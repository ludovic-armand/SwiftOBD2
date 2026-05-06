//
//  FuelComputer.swift
//  SwiftOBD2Dash
//
//  Computes instant fuel consumption, trip-average consumption, and range
//  from MAF + lambda + speed + fuel level. None of these are direct OBD-II
//  PIDs — the standard doesn't expose "fuel consumption" — so everything
//  here is a calculation.
//
//  Math, in plain English:
//    1.  MAF gives us grams-per-second of AIR entering the engine.
//    2.  Divide by the air-fuel ratio to get grams-per-second of FUEL.
//        (Stoichiometric AFR is ~14.7 for gasoline, ~14.5 for diesel,
//         scaled by commanded lambda when we have it.)
//    3.  Divide by fuel density to get litres-per-second.
//    4.  Multiply by 3600 → litres-per-hour.
//    5.  Divide by speed (km/h) and multiply by 100 → litres-per-100km.
//

import Foundation
import Observation
import SwiftOBD2

// MARK: - Fuel type

enum FuelType: String, CaseIterable, Identifiable, Codable {
    case gasoline
    case diesel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gasoline: return "Gasoline"
        case .diesel:   return "Diesel"
        }
    }

    /// Stoichiometric air-fuel ratio (g of air per g of fuel for complete combustion).
    var stoichiometricAFR: Double {
        switch self {
        case .gasoline: return 14.7
        case .diesel:   return 14.5
        }
    }

    /// Density at 15 °C in g / L.
    var densityGramsPerLitre: Double {
        switch self {
        case .gasoline: return 745
        case .diesel:   return 832
        }
    }
}

// MARK: - Computer

@Observable
final class FuelComputer {

    // MARK: User-configurable settings (persisted)

    var tankSizeLitres: Double {
        didSet { UserDefaults.standard.set(tankSizeLitres, forKey: Self.tankKey) }
    }
    var fuelType: FuelType {
        didSet { UserDefaults.standard.set(fuelType.rawValue, forKey: Self.fuelTypeKey) }
    }

    // MARK: Live computed outputs (updated in `update`)

    /// Litres burned per 100 km right now. nil if speed is too low to be meaningful.
    var instantLPer100km: Double?
    /// Litres per hour right now (always defined when MAF is available, even at idle).
    var instantLPerHour: Double?
    /// Trip average L/100km. nil until we've accumulated some distance.
    var tripAvgLPer100km: Double?
    /// Estimated remaining range in km. nil if we don't have fuel level or recent average.
    var rangeKm: Double?

    /// Cumulative state for the current trip.
    var fuelUsedThisTripL: Double = 0
    var distanceThisTripKm: Double = 0

    /// True if MAF is present and we're producing real numbers.
    var hasFuelData: Bool = false

    // MARK: Internals

    /// Rolling window of recent (fuel L/h, distance km/h) for range estimation —
    /// lets us ignore the long warm-up idle period when computing range.
    private struct RecentSample {
        let timestamp: Date
        let fuelLPerH: Double
        let speedKmH: Double
    }
    private var recentWindow: [RecentSample] = []
    private let recentWindowSeconds: TimeInterval = 5 * 60   // last 5 minutes

    private var lastUpdateAt: Date?

    // MARK: Persistence keys

    private static let tankKey     = "fuel.tankSizeLitres"
    private static let fuelTypeKey = "fuel.type"

    init() {
        let defaults = UserDefaults.standard
        let storedTank = defaults.double(forKey: Self.tankKey)
        self.tankSizeLitres = storedTank > 0 ? storedTank : 50.0   // sensible default
        if let raw = defaults.string(forKey: Self.fuelTypeKey),
           let ft = FuelType(rawValue: raw) {
            self.fuelType = ft
        } else {
            self.fuelType = .gasoline
        }
    }

    // MARK: - Update

    /// Call this on every OBD poll cycle.
    /// - Parameters:
    ///   - readings: the latest PID readings dictionary.
    ///   - now: injectable for tests.
    func update(readings: [OBDCommand: MeasurementResult], now: Date = .now) {
        // Pull what we need.
        let mafGramsPerSecond = readings[.mode1(.maf)]?.value
        let speedKmH          = readings[.mode1(.speed)]?.value ?? 0
        let fuelLevelPct      = readings[.mode1(.fuelLevel)]?.value
        // Lambda is optional — fall back to 1.0 (stoichiometric).
        let lambda            = readings[.mode1(.commandedEquivRatio)]?.value ?? 1.0

        guard let maf = mafGramsPerSecond, maf > 0 else {
            // No MAF → can't compute. Mark unsupported and skip.
            hasFuelData = false
            instantLPerHour = nil
            instantLPer100km = nil
            // Still update range using whatever we already have so the tile doesn't go blank.
            updateRange(fuelLevelPct: fuelLevelPct)
            lastUpdateAt = now
            return
        }
        hasFuelData = true

        // Step 1–4: compute current fuel flow.
        let actualAFR = fuelType.stoichiometricAFR * max(0.5, lambda)   // clamp lambda to a sane floor
        let fuelGramsPerSecond = maf / actualAFR
        let fuelLitresPerSecond = fuelGramsPerSecond / fuelType.densityGramsPerLitre
        let fuelLitresPerHour   = fuelLitresPerSecond * 3600.0

        instantLPerHour = fuelLitresPerHour
        instantLPer100km = (speedKmH > 5) ? (fuelLitresPerHour * 100.0 / speedKmH) : nil

        // Step 5: integrate over dt for trip totals.
        if let last = lastUpdateAt {
            let dt = now.timeIntervalSince(last)
            // Defensive: skip if dt is unreasonable (paused / clock change).
            if dt > 0, dt < 10 {
                let fuelThisStep = fuelLitresPerSecond * dt
                let distanceThisStep = (speedKmH / 3600.0) * dt   // (km/s) × s
                fuelUsedThisTripL  += fuelThisStep
                distanceThisTripKm += distanceThisStep

                // Push into recent window.
                recentWindow.append(RecentSample(timestamp: now,
                                                 fuelLPerH: fuelLitresPerHour,
                                                 speedKmH: speedKmH))
                trimRecentWindow(now: now)
            }
        }
        lastUpdateAt = now

        // Trip average — only meaningful past ~100 m.
        if distanceThisTripKm > 0.1 {
            tripAvgLPer100km = (fuelUsedThisTripL * 100.0) / distanceThisTripKm
        }

        // Range based on fuel level + recent rolling avg.
        updateRange(fuelLevelPct: fuelLevelPct)
    }

    // MARK: - Trip lifecycle

    /// Reset trip totals. TripRecorder calls this at the start of a new trip.
    func resetTrip() {
        fuelUsedThisTripL = 0
        distanceThisTripKm = 0
        tripAvgLPer100km = nil
        recentWindow.removeAll()
        lastUpdateAt = nil
    }

    // MARK: - Range

    private func updateRange(fuelLevelPct: Double?) {
        guard let pct = fuelLevelPct, pct > 0 else {
            rangeKm = nil
            return
        }
        let recentAvg = recentAverageLPer100km()
        // Fall back to trip average if we don't have enough recent samples.
        let avg = recentAvg ?? tripAvgLPer100km
        guard let consumption = avg, consumption > 0.5 else {
            rangeKm = nil
            return
        }
        let fuelRemainingL = (pct / 100.0) * tankSizeLitres
        rangeKm = (fuelRemainingL * 100.0) / consumption
    }

    /// Average L/100km over the last `recentWindowSeconds`, weighted by time.
    /// Ignores idle periods (speed < 5 km/h) so warm-up doesn't tank the estimate.
    private func recentAverageLPer100km() -> Double? {
        guard recentWindow.count >= 5 else { return nil }
        var totalFuelL = 0.0
        var totalKm    = 0.0
        var lastTs: Date?
        for sample in recentWindow where sample.speedKmH > 5 {
            if let last = lastTs {
                let dt = sample.timestamp.timeIntervalSince(last)
                if dt > 0, dt < 10 {
                    let dtH = dt / 3600.0
                    totalFuelL += sample.fuelLPerH * dtH
                    totalKm    += sample.speedKmH * dtH
                }
            }
            lastTs = sample.timestamp
        }
        guard totalKm > 0.5 else { return nil }
        return totalFuelL * 100.0 / totalKm
    }

    private func trimRecentWindow(now: Date) {
        let cutoff = now.addingTimeInterval(-recentWindowSeconds)
        recentWindow.removeAll { $0.timestamp < cutoff }
    }
}
