//
//  SensorKnowledge.swift
//  SwiftOBD2Dash
//
//  Plain-English knowledge for live OBD-II sensors.
//  Each entry knows what the sensor measures, the normal range, and how to
//  evaluate any single value as Normal / Marginal / Concerning / Critical.
//
//  These thresholds are conservative and intended for a "should I worry?"
//  glance — not a substitute for a service manual. Many sensors are
//  context-dependent (idle vs cruise, cold vs warm) and the description
//  field calls those out.
//

import Foundation
import SwiftUI
import SwiftOBD2

// MARK: - Health

enum SensorHealth {
    case unknown        // value isn't trustworthy yet (engine cold, idling, etc.)
    case normal
    case marginal
    case concerning
    case critical

    var color: Color {
        switch self {
        case .unknown:     return Theme.textMuted
        case .normal:      return Theme.accent
        case .marginal:    return Theme.warning
        case .concerning:  return .orange
        case .critical:    return Theme.critical
        }
    }

    var label: String {
        switch self {
        case .unknown:     return "—"
        case .normal:      return "Normal"
        case .marginal:    return "Watch"
        case .concerning:  return "Concerning"
        case .critical:    return "Critical"
        }
    }
}

// MARK: - Category

enum SensorCategory: String, CaseIterable, Identifiable {
    case engine     = "Engine"
    case fuel       = "Fuel system"
    case air        = "Air & intake"
    case ignition   = "Ignition"
    case emissions  = "Emissions"
    case oxygen     = "Oxygen sensors"
    case electrical = "Electrical"
    case info       = "Info"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .engine:     return "engine.combustion"
        case .fuel:       return "fuelpump"
        case .air:        return "wind"
        case .ignition:   return "bolt"
        case .emissions:  return "leaf"
        case .oxygen:     return "circle.hexagongrid"
        case .electrical: return "battery.100"
        case .info:       return "info.circle"
        }
    }
}

// MARK: - Knowledge struct

struct SensorKnowledge {
    let title: String
    /// One-paragraph plain-English explanation: what this is and why it matters.
    let description: String
    /// Short note on normal range (shown next to the value).
    let normalRangeNote: String
    /// Likely causes when the value is too high or too low.
    let highMeans: String?
    let lowMeans: String?
    let category: SensorCategory
    /// Closure to evaluate health from a raw value. Receives the raw `Double`
    /// from `MeasurementResult.value`. Should be cheap.
    let evaluate: (Double) -> SensorHealth
}

// MARK: - Lookup

enum SensorKnowledgeBase {

    /// Returns curated knowledge for a PID, or `nil` if we don't have an entry yet.
    static func entry(for pid: OBDCommand) -> SensorKnowledge? {
        all[pid]
    }

    /// All PIDs we have knowledge for, in a deterministic order.
    static var allPIDs: [OBDCommand] { Array(all.keys) }

    // MARK: - Curated knowledge

    static let all: [OBDCommand: SensorKnowledge] = [

        // ────────────────────────────────────────────────────────────────────
        // Engine basics
        // ────────────────────────────────────────────────────────────────────

        .mode1(.rpm): SensorKnowledge(
            title: "Engine RPM",
            description: "How fast the crankshaft is spinning. Idle is normally 600–900 RPM warm. Above ~6500 you're approaching redline on most gas engines.",
            normalRangeNote: "600–900 idle warm",
            highMeans: "Sustained high RPM under no load can mean a stuck idle valve or vacuum leak.",
            lowMeans: "Low or unstable idle suggests vacuum leak, dirty throttle body, or weak fuel delivery.",
            category: .engine,
            evaluate: { v in
                if v <= 0 { return .unknown }
                if v < 400 { return .concerning }   // about to stall
                if v <= 1100 { return .normal }     // idle window
                if v < 6500 { return .normal }      // driving
                if v < 7000 { return .marginal }    // approaching redline
                return .critical
            }
        ),

        .mode1(.coolantTemp): SensorKnowledge(
            title: "Coolant temperature",
            description: "Engine coolant temperature. After warm-up, it should sit in a tight band thanks to the thermostat. Spikes mean the engine is overheating; dropping below normal usually means a stuck-open thermostat.",
            normalRangeNote: "85–105 °C warm",
            highMeans: "Low coolant, failing water pump, stuck thermostat, blocked radiator, or a head-gasket issue.",
            lowMeans: "Stuck-open thermostat (most common), or in cold weather just hasn't warmed up yet.",
            category: .engine,
            evaluate: { v in
                if v < 50 { return .unknown }       // still warming
                if v < 75 { return .marginal }      // running cooler than ideal
                if v <= 105 { return .normal }
                if v < 110 { return .marginal }
                if v < 115 { return .concerning }
                return .critical
            }
        ),

        .mode1(.engineLoad): SensorKnowledge(
            title: "Engine load",
            description: "How hard the engine is working as a percent of its maximum at the current RPM. Idle is usually 15–30%. Highway cruise is 25–50%. Climbing a hill at full throttle approaches 100%.",
            normalRangeNote: "15–30% idle, up to ~85% normal",
            highMeans: "Sustained high load with low RPM can indicate lugging, transmission issues, or a heavy load.",
            lowMeans: nil,
            category: .engine,
            evaluate: { v in
                if v <= 90 { return .normal }
                if v <= 95 { return .marginal }
                return .concerning
            }
        ),

        .mode1(.absoluteLoad): SensorKnowledge(
            title: "Absolute engine load",
            description: "Same idea as engine load but referenced to absolute air mass at standard conditions. Useful for spotting boost on turbo cars (>100% means forced induction).",
            normalRangeNote: "<95% naturally aspirated",
            highMeans: "Above 100% on a turbo car is normal at boost. On a naturally aspirated engine, sustained >95% suggests sensor or air-flow issue.",
            lowMeans: nil,
            category: .engine,
            evaluate: { v in
                if v <= 100 { return .normal }
                if v <= 200 { return .normal }   // turbo boost
                return .marginal
            }
        ),

        .mode1(.runTime): SensorKnowledge(
            title: "Run time since start",
            description: "How long the engine has been running since you started the car. Informational — used by emissions monitors that need a minimum run time to complete their checks.",
            normalRangeNote: "Counts up while running",
            highMeans: nil, lowMeans: nil,
            category: .info,
            evaluate: { _ in .normal }
        ),

        .mode1(.timingAdvance): SensorKnowledge(
            title: "Ignition timing advance",
            description: "Degrees before top-dead-centre that the spark fires. The ECU advances timing for power and pulls it back if it detects knock. Persistent low timing under load can mean the knock sensor is finding a problem.",
            normalRangeNote: "10–30° typical",
            highMeans: "Very high timing isn't usually a fault, just aggressive tuning.",
            lowMeans: "Pulled-back timing (negative or very low) under load suggests knock — bad gas, carbon, or overheating.",
            category: .ignition,
            evaluate: { v in
                if v < -10 { return .concerning }
                if v < 0 { return .marginal }
                return .normal
            }
        ),

        // ────────────────────────────────────────────────────────────────────
        // Fuel system
        // ────────────────────────────────────────────────────────────────────

        .mode1(.fuelLevel): SensorKnowledge(
            title: "Fuel level",
            description: "Reported tank level. Many vehicles don't return this PID accurately or at all — your in-cluster gauge is the source of truth.",
            normalRangeNote: "0–100%",
            highMeans: nil,
            lowMeans: "Plan a fuel stop.",
            category: .fuel,
            evaluate: { v in
                if v < 5 { return .marginal }
                return .normal
            }
        ),

        .mode1(.shortFuelTrim1): SensorKnowledge(
            title: "Short-term fuel trim (Bank 1)",
            description: "Real-time correction the ECU is applying to the fuel mix on bank 1. Positive = adding fuel because the O2 sensor sees too much air (lean). Negative = pulling fuel because the mixture is rich. Bounces a few percent constantly — that's normal.",
            normalRangeNote: "±5% normal, ±10% acceptable",
            highMeans: "Persistent positive trim = lean condition. Look for vacuum leaks, weak fuel pump, dirty MAF, leaking injector seal.",
            lowMeans: "Persistent negative trim = rich condition. Leaking injector, stuck-open evap purge, contaminated O2 sensor.",
            category: .fuel,
            evaluate: trimEval
        ),

        .mode1(.longFuelTrim1): SensorKnowledge(
            title: "Long-term fuel trim (Bank 1)",
            description: "The learned fuel correction the ECU has built up over time on bank 1. Combined with short-term trim it should average within ±10%. If long-term trim parks at +15% or more, the engine has been running lean for a while.",
            normalRangeNote: "±5% normal, ±10% acceptable",
            highMeans: "Same causes as STFT but established. Often pre-DTC for P0171 (system too lean, bank 1).",
            lowMeans: "Same causes as STFT but established. Often pre-DTC for P0172 (system too rich, bank 1).",
            category: .fuel,
            evaluate: trimEval
        ),

        .mode1(.shortFuelTrim2): SensorKnowledge(
            title: "Short-term fuel trim (Bank 2)",
            description: "Same as bank 1 but for the second cylinder bank on V engines. Compare to bank 1 — if one bank is +12% and the other is 0%, the problem is on that bank only.",
            normalRangeNote: "±5% normal, ±10% acceptable",
            highMeans: "Lean condition on bank 2. Vacuum leak, injector, MAF sensor.",
            lowMeans: "Rich condition on bank 2.",
            category: .fuel,
            evaluate: trimEval
        ),

        .mode1(.longFuelTrim2): SensorKnowledge(
            title: "Long-term fuel trim (Bank 2)",
            description: "Long-term correction for bank 2. Persistent imbalance between bank 1 and bank 2 trims is a strong signal that the issue is mechanical on one side, not a global problem like a bad fuel filter.",
            normalRangeNote: "±5% normal, ±10% acceptable",
            highMeans: "Lean bias on bank 2 only. Often P0174.",
            lowMeans: "Rich bias on bank 2 only.",
            category: .fuel,
            evaluate: trimEval
        ),

        .mode1(.fuelPressure): SensorKnowledge(
            title: "Fuel pressure (manifold)",
            description: "Fuel rail pressure as seen at the intake manifold side. Many modern direct-injection engines don't return a useful value here — they use the rail-pressure PIDs instead.",
            normalRangeNote: "Varies by vehicle",
            highMeans: nil, lowMeans: "Weak fuel pump, plugged filter, leaking regulator.",
            category: .fuel,
            evaluate: { _ in .normal }
        ),

        .mode1(.commandedEquivRatio): SensorKnowledge(
            title: "Commanded lambda (λ)",
            description: "Fuel ratio the ECU is asking the injectors to deliver. λ = 1.00 is stoichiometric (perfect air/fuel mix). At wide-open throttle, the ECU commands ~0.80–0.85 (rich) for power and cooling.",
            normalRangeNote: "0.80–1.05 depending on load",
            highMeans: "λ > 1.05 sustained = lean command (deceleration cut-off is normal at high RPM, otherwise unusual).",
            lowMeans: "λ < 0.80 sustained = very rich command (open-loop warm-up, full throttle).",
            category: .fuel,
            evaluate: { v in
                if v <= 0 { return .unknown }
                if v >= 0.78 && v <= 1.10 { return .normal }
                return .marginal
            }
        ),

        .mode1(.fuelStatus): SensorKnowledge(
            title: "Fuel system status",
            description: "Whether the fuel system is in open-loop (ignoring O2 sensors) or closed-loop (trimming based on O2 readings). Cold start and full throttle use open-loop. Cruising and idle should be closed-loop on a healthy car.",
            normalRangeNote: "Closed-loop after warm-up",
            highMeans: nil, lowMeans: nil,
            category: .fuel,
            evaluate: { _ in .normal }
        ),

        // ────────────────────────────────────────────────────────────────────
        // Air & intake
        // ────────────────────────────────────────────────────────────────────

        .mode1(.intakeTemp): SensorKnowledge(
            title: "Intake air temperature",
            description: "Temperature of the air entering the engine. Should track close to ambient when driving. After a soak in the sun or with an under-hood heat-soaked sensor, it can read much higher at idle.",
            normalRangeNote: "Within 10°C of ambient driving",
            highMeans: "Heat-soaked at idle is normal. Sustained high IAT while driving suggests airflow restriction or sensor fault.",
            lowMeans: nil,
            category: .air,
            evaluate: { v in
                if v < -20 { return .marginal }     // sensor likely faulty / disconnected
                if v < 60 { return .normal }
                if v < 80 { return .marginal }
                return .concerning
            }
        ),

        .mode1(.throttlePos): SensorKnowledge(
            title: "Throttle position",
            description: "How far open the throttle plate is. At idle should sit around 12–18% (closed throttle isn't 0% — there's a built-in offset). Pedal-to-the-floor reads ~85–100%.",
            normalRangeNote: "12–18% closed, ~100% WOT",
            highMeans: nil,
            lowMeans: "Reading 0% with the engine running is a sensor or wiring issue.",
            category: .air,
            evaluate: { _ in .normal }
        ),

        .mode1(.relativeThrottlePos): SensorKnowledge(
            title: "Relative throttle position",
            description: "Throttle position with the closed-throttle offset removed. 0% really means foot off the gas. Useful when you're checking pedal-to-throttle linearity on drive-by-wire systems.",
            normalRangeNote: "0% closed, 100% WOT",
            highMeans: nil, lowMeans: nil,
            category: .air,
            evaluate: { _ in .normal }
        ),

        .mode1(.intakePressure): SensorKnowledge(
            title: "Intake manifold pressure (MAP)",
            description: "Pressure inside the intake manifold. At idle a healthy engine pulls vacuum, so MAP reads well below atmospheric (~30–40 kPa). At full throttle on a NA engine it equals atmospheric (~95–101 kPa). On a turbo engine, boost pushes it higher.",
            normalRangeNote: "30–40 idle, ~100 WOT NA",
            highMeans: "High idle MAP suggests vacuum leak or stuck EGR valve.",
            lowMeans: nil,
            category: .air,
            evaluate: { _ in .normal }
        ),

        .mode1(.maf): SensorKnowledge(
            title: "Mass air flow (MAF)",
            description: "Grams per second of air entering the engine. Idle is usually 2–5 g/s; cruise is 8–25 g/s; full throttle on a small engine is 70–130 g/s. A failing MAF often reads low — the engine starves and you see lean fuel trims.",
            normalRangeNote: "2–5 g/s idle warm",
            highMeans: nil,
            lowMeans: "Dirty or failing MAF, intake leak before the sensor, or clogged filter. Often pairs with positive fuel trims.",
            category: .air,
            evaluate: { v in
                if v < 1.5 { return .marginal }     // probably idle but very low
                return .normal
            }
        ),

        .mode1(.barometricPressure): SensorKnowledge(
            title: "Barometric pressure",
            description: "Atmospheric pressure as measured by the ECU. Mostly informational — the ECU uses it to adjust fueling at altitude. Should track sea-level (~101 kPa) at low elevation; ~85 kPa at 1500m elevation.",
            normalRangeNote: "85–101 kPa typical",
            highMeans: nil, lowMeans: nil,
            category: .air,
            evaluate: { _ in .normal }
        ),

        .mode1(.ambientAirTemp): SensorKnowledge(
            title: "Ambient air temperature",
            description: "Outside-air temperature reported by the ECU. Differs from the intake air temp because the sensor is in front of the radiator. Used by the climate-control system.",
            normalRangeNote: "Matches outside temperature",
            highMeans: nil, lowMeans: nil,
            category: .air,
            evaluate: { _ in .normal }
        ),

        // ────────────────────────────────────────────────────────────────────
        // Emissions
        // ────────────────────────────────────────────────────────────────────

        .mode1(.commandedEGR): SensorKnowledge(
            title: "Commanded EGR",
            description: "How much exhaust gas the ECU is asking the EGR valve to recirculate into the intake. Helps with NOx and combustion temperature. 0% at idle and full throttle; opens during light cruise.",
            normalRangeNote: "0% idle, opens at cruise",
            highMeans: nil, lowMeans: nil,
            category: .emissions,
            evaluate: { _ in .normal }
        ),

        .mode1(.EGRError): SensorKnowledge(
            title: "EGR error",
            description: "Difference between commanded EGR and actual EGR. Should hover near 0%. Persistent error means the valve is stuck or the position sensor is lying.",
            normalRangeNote: "±5% normal",
            highMeans: "EGR valve is stuck or carbon-fouled.",
            lowMeans: "Same — EGR system can't hit the commanded position.",
            category: .emissions,
            evaluate: { v in
                let mag = abs(v)
                if mag <= 5 { return .normal }
                if mag <= 15 { return .marginal }
                return .concerning
            }
        ),

        .mode1(.evaporativePurge): SensorKnowledge(
            title: "Evap purge command",
            description: "How much fuel-tank vapor the ECU is venting into the intake. 0% at cold start, opens up after warm-up. If purge is high at idle, you'll often see negative fuel trims as a side effect.",
            normalRangeNote: "0% cold, varies warm",
            highMeans: nil, lowMeans: nil,
            category: .emissions,
            evaluate: { _ in .normal }
        ),

        .mode1(.evapVaporPressure): SensorKnowledge(
            title: "Evap vapor pressure",
            description: "Pressure inside the fuel tank / evap system. Used for leak detection (the P044x family of codes). Hovers near ambient when at rest.",
            normalRangeNote: "Near 0 kPa idle",
            highMeans: nil, lowMeans: nil,
            category: .emissions,
            evaluate: { _ in .normal }
        ),

        .mode1(.catalystTempB1S1): SensorKnowledge(
            title: "Catalytic converter temp (B1S1)",
            description: "Temperature inside the catalytic converter (bank 1, sensor 1). 400–800°C is normal under load. Sustained over 900°C cooks the cat — caused by misfires dumping raw fuel into the exhaust.",
            normalRangeNote: "400–800°C under load",
            highMeans: "Misfire dumping fuel into the exhaust, or very rich mixture. Damaging the converter quickly.",
            lowMeans: "Cold cat at idle is normal. Stays cold = cat may be plugged or sensor faulty.",
            category: .emissions,
            evaluate: { v in
                if v < 200 { return .unknown }      // not warmed up yet
                if v < 850 { return .normal }
                if v < 950 { return .marginal }
                return .concerning
            }
        ),

        .mode1(.distanceWMIL): SensorKnowledge(
            title: "Distance with MIL on",
            description: "How far the car has been driven with the check-engine light illuminated. Useful for emissions testing — many jurisdictions require this to be a low number.",
            normalRangeNote: "0 km if no DTCs",
            highMeans: "The light has been on for a while. Get the codes scanned.",
            lowMeans: nil,
            category: .info,
            evaluate: { v in
                if v == 0 { return .normal }
                if v < 100 { return .marginal }
                return .concerning
            }
        ),

        .mode1(.distanceSinceDTCCleared): SensorKnowledge(
            title: "Distance since codes cleared",
            description: "How far you've driven since the DTCs were last cleared. Indicates whether emissions monitors have had time to complete a full drive cycle.",
            normalRangeNote: "Counts up after a clear",
            highMeans: nil, lowMeans: nil,
            category: .info,
            evaluate: { _ in .normal }
        ),

        .mode1(.warmUpsSinceDTCCleared): SensorKnowledge(
            title: "Warm-ups since codes cleared",
            description: "Count of full cold-start-to-operating-temperature cycles since codes were cleared. Most emissions monitors need 3–5 warm-ups to run.",
            normalRangeNote: "Counts up after a clear",
            highMeans: nil, lowMeans: nil,
            category: .info,
            evaluate: { _ in .normal }
        ),

        // ────────────────────────────────────────────────────────────────────
        // O2 sensors (the simple narrow-band ones)
        // ────────────────────────────────────────────────────────────────────

        .mode1(.O2Bank1Sensor1): SensorKnowledge(
            title: "O₂ sensor B1S1 (upstream)",
            description: "Narrow-band oxygen sensor before the cat on bank 1. Should swing rapidly between ~0.1V (lean) and ~0.9V (rich) several times a second when the engine is in closed-loop. A sensor stuck in the middle is dead.",
            normalRangeNote: "Swings 0.1–0.9 V",
            highMeans: "Stuck high = rich condition or bad sensor.",
            lowMeans: "Stuck low = lean condition or bad sensor.",
            category: .oxygen,
            evaluate: { _ in .normal }   // hard to judge from a single reading
        ),

        .mode1(.O2Bank1Sensor2): SensorKnowledge(
            title: "O₂ sensor B1S2 (downstream)",
            description: "Post-cat sensor on bank 1. Should be a steady value around 0.6–0.8V when the cat is healthy. If it mirrors the upstream sensor's rapid swings, the converter isn't working — common P0420 cause.",
            normalRangeNote: "Steady 0.6–0.8 V",
            highMeans: nil, lowMeans: nil,
            category: .oxygen,
            evaluate: { _ in .normal }
        ),

        .mode1(.O2Bank2Sensor1): SensorKnowledge(
            title: "O₂ sensor B2S1 (upstream)",
            description: "Same as B1S1 but on the second bank of a V engine. Should swing rapidly when in closed-loop.",
            normalRangeNote: "Swings 0.1–0.9 V",
            highMeans: nil, lowMeans: nil,
            category: .oxygen,
            evaluate: { _ in .normal }
        ),

        .mode1(.O2Bank2Sensor2): SensorKnowledge(
            title: "O₂ sensor B2S2 (downstream)",
            description: "Post-cat sensor on bank 2. Steady value if the cat is doing its job.",
            normalRangeNote: "Steady 0.6–0.8 V",
            highMeans: nil, lowMeans: nil,
            category: .oxygen,
            evaluate: { _ in .normal }
        ),

        // ────────────────────────────────────────────────────────────────────
        // Electrical
        // ────────────────────────────────────────────────────────────────────

        .mode1(.controlModuleVoltage): SensorKnowledge(
            title: "Control-module voltage",
            description: "Voltage at the engine ECU. With the engine OFF: 12.4–12.7V is a healthy battery. With the engine RUNNING: the alternator should hold it at 13.7–14.7V. Below 12V running means the alternator isn't keeping up.",
            normalRangeNote: "13.7–14.7 V running",
            highMeans: "Above 15V means voltage regulator is overcharging — kills batteries fast.",
            lowMeans: "Below 13V running means alternator isn't charging. Below 11V the car is about to die.",
            category: .electrical,
            evaluate: { v in
                if v < 11.0 { return .critical }
                if v < 12.4 { return .concerning }
                if v <= 14.7 { return .normal }
                if v <= 15.2 { return .marginal }
                return .concerning
            }
        )
    ]

    // MARK: - Reusable evaluators

    /// Standard fuel-trim evaluator: ±5% normal, ±10% marginal, ±20% concerning, beyond critical.
    private static let trimEval: (Double) -> SensorHealth = { v in
        let mag = abs(v)
        if mag <= 5  { return .normal }
        if mag <= 10 { return .marginal }
        if mag <= 20 { return .concerning }
        return .critical
    }
}
