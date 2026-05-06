//
//  TripRecorder.swift
//  SwiftOBD2Dash
//
//  Watches the OBDController. When the car is connected and the engine is
//  actually running (rpm > idle threshold for a few seconds), we open a Trip
//  and start writing samples. When rpm drops to 0 for long enough, we close it.
//

import Foundation
import SwiftData
import SwiftUI
import Observation

@Observable
final class TripRecorder {
    /// Currently-recording trip, if any.
    private(set) var currentTrip: Trip?

    private let modelContext: ModelContext
    private let obd: OBDController

    /// Timer that polls the OBD controller's latest readings and writes a sample.
    private var sampleTimer: Timer?

    /// Sliding window of recent rpm so we can decide when the car has truly stopped.
    private var rpmZeroSeconds: Int = 0

    /// Tunables.
    private let sampleInterval: TimeInterval = 2.0
    private let stopAfterSecondsAtZeroRPM: Int = 30   // car is off

    init(modelContext: ModelContext, obd: OBDController) {
        self.modelContext = modelContext
        self.obd = obd
    }

    func start() {
        guard sampleTimer == nil else { return }
        sampleTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        endCurrentTrip()
    }

    // MARK: - Tick

    private func tick() {
        let rpm = obd.rpm ?? 0
        let speed = obd.speed ?? 0

        // Ignition probably off and engine not turning — close any open trip.
        if rpm <= 0 {
            rpmZeroSeconds += Int(sampleInterval)
            if rpmZeroSeconds >= stopAfterSecondsAtZeroRPM {
                endCurrentTrip()
            }
            return
        }

        rpmZeroSeconds = 0

        // Engine turning, but no trip yet — start one.
        if currentTrip == nil {
            let trip = Trip(startedAt: .now)
            modelContext.insert(trip)
            currentTrip = trip
            // Reset the fuel computer's trip totals so this new trip's averages
            // start from zero rather than carrying over from the previous drive.
            obd.fuel.resetTrip()
        }

        guard let trip = currentTrip else { return }

        // Append a sample.
        let sample = TripSample(
            timestamp: .now,
            rpm: obd.rpm,
            speedKPH: obd.speed,
            coolantC: obd.coolant,
            throttlePct: obd.throttle,
            loadPct: obd.load,
            voltage: obd.voltage
        )
        sample.trip = trip
        modelContext.insert(sample)

        // Update aggregates.
        trip.sampleCount += 1
        trip.maxRPM      = max(trip.maxRPM, rpm)
        trip.maxSpeedKPH = max(trip.maxSpeedKPH, speed)
        if let c = obd.coolant { trip.maxCoolantC = max(trip.maxCoolantC, c) }

        // Rolling average — cheap incremental mean.
        let prevAvg = trip.avgSpeedKPH
        let n = Double(trip.sampleCount)
        trip.avgSpeedKPH = prevAvg + (speed - prevAvg) / n

        // Mirror the fuel computer's running totals onto the trip so they
        // survive even after the FuelComputer resets for the next drive.
        trip.fuelUsedL  = obd.fuel.fuelUsedThisTripL
        trip.distanceKm = obd.fuel.distanceThisTripKm

        try? modelContext.save()
    }

    private func endCurrentTrip() {
        guard let trip = currentTrip else { return }
        trip.endedAt = .now
        // Drop trips shorter than 30s — that's just the engine bumping over.
        if trip.duration < 30 {
            modelContext.delete(trip)
        }
        try? modelContext.save()
        currentTrip = nil
        rpmZeroSeconds = 0
    }
}

// MARK: - Environment plumbing

private struct TripRecorderKey: EnvironmentKey {
    static let defaultValue: TripRecorder? = nil
}

extension EnvironmentValues {
    var tripRecorder: TripRecorder? {
        get { self[TripRecorderKey.self] }
        set { self[TripRecorderKey.self] = newValue }
    }
}
