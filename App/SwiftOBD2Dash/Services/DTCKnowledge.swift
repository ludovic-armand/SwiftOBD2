//
//  DTCKnowledge.swift
//  SwiftOBD2Dash
//
//  Translates raw DTC codes into something a human can act on.
//  The SwiftOBD2 package already attaches a SAE description to each TroubleCode;
//  this file adds severity, plain-English summary, and "what to check first".
//

import Foundation
import SwiftUI

enum DTCSeverity {
    case info       // probably benign / informational
    case caution    // monitor — driveable but worth checking
    case serious    // get it looked at soon
    case critical   // pull over / don't drive

    var color: Color {
        switch self {
        case .info:     return Theme.textSecondary
        case .caution:  return Theme.warning
        case .serious:  return Color.orange
        case .critical: return Theme.critical
        }
    }

    var label: String {
        switch self {
        case .info:     return "Informational"
        case .caution:  return "Caution"
        case .serious:  return "Serious"
        case .critical: return "Critical"
        }
    }
}

struct DTCExplanation {
    let plainEnglish: String
    let likelyCauses: [String]
    let severity: DTCSeverity
}

enum DTCKnowledge {

    /// Look up an explanation for a given code (e.g. "P0420").
    /// Falls back to a sensible default based on the code prefix.
    static func explanation(for code: String) -> DTCExplanation {
        if let exact = exactMatches[code.uppercased()] { return exact }
        return fallback(for: code)
    }

    /// Hand-curated explanations for the most common consumer-facing codes.
    /// (Kept short on purpose — we want a glanceable summary, not a service manual.)
    private static let exactMatches: [String: DTCExplanation] = [

        "P0171": .init(
            plainEnglish: "Engine running too lean on bank 1 — too much air relative to fuel.",
            likelyCauses: ["Vacuum / intake leak", "Dirty MAF sensor", "Weak fuel pump", "Clogged fuel filter"],
            severity: .serious
        ),
        "P0174": .init(
            plainEnglish: "Engine running too lean on bank 2 — same idea as P0171, other side.",
            likelyCauses: ["Vacuum / intake leak", "Dirty MAF sensor", "Weak fuel pump"],
            severity: .serious
        ),
        "P0300": .init(
            plainEnglish: "Random / multiple cylinder misfire detected.",
            likelyCauses: ["Spark plugs / coils", "Vacuum leak", "Low fuel pressure", "Bad injector"],
            severity: .critical
        ),
        "P0301": .init(
            plainEnglish: "Cylinder 1 is misfiring.",
            likelyCauses: ["Spark plug", "Ignition coil", "Injector", "Compression on that cylinder"],
            severity: .serious
        ),
        "P0302": .init(
            plainEnglish: "Cylinder 2 is misfiring.",
            likelyCauses: ["Spark plug", "Ignition coil", "Injector"],
            severity: .serious
        ),
        "P0303": .init(
            plainEnglish: "Cylinder 3 is misfiring.",
            likelyCauses: ["Spark plug", "Ignition coil", "Injector"],
            severity: .serious
        ),
        "P0304": .init(
            plainEnglish: "Cylinder 4 is misfiring.",
            likelyCauses: ["Spark plug", "Ignition coil", "Injector"],
            severity: .serious
        ),
        "P0420": .init(
            plainEnglish: "Catalytic converter (bank 1) isn't working as well as it should.",
            likelyCauses: ["Aging catalytic converter", "Bad rear O2 sensor", "Exhaust leak before the cat"],
            severity: .caution
        ),
        "P0430": .init(
            plainEnglish: "Catalytic converter (bank 2) isn't working as well as it should.",
            likelyCauses: ["Aging catalytic converter", "Bad rear O2 sensor", "Exhaust leak"],
            severity: .caution
        ),
        "P0440": .init(
            plainEnglish: "Evap system leak — typically a loose or bad gas cap.",
            likelyCauses: ["Loose / cracked gas cap", "Cracked evap hose", "Bad purge valve"],
            severity: .info
        ),
        "P0441": .init(
            plainEnglish: "Evap purge flow is wrong — purge valve probably stuck.",
            likelyCauses: ["Stuck purge valve", "Vacuum leak in evap line"],
            severity: .info
        ),
        "P0442": .init(
            plainEnglish: "Small evap leak — most often the gas cap.",
            likelyCauses: ["Loose / faulty gas cap", "Tiny crack in an evap hose"],
            severity: .info
        ),
        "P0455": .init(
            plainEnglish: "Large evap leak — gas cap is off, or a hose came loose.",
            likelyCauses: ["Gas cap missing or not clicked", "Disconnected evap hose"],
            severity: .info
        ),
        "P0700": .init(
            plainEnglish: "Transmission control module reports a fault. Pull the transmission codes for detail.",
            likelyCauses: ["Companion code in transmission module", "Wiring / sensor on the trans"],
            severity: .serious
        ),
        "P0128": .init(
            plainEnglish: "Coolant isn't reaching operating temperature fast enough.",
            likelyCauses: ["Stuck-open thermostat", "Low coolant", "Bad coolant temp sensor"],
            severity: .caution
        ),
        "P0011": .init(
            plainEnglish: "Camshaft (intake, bank 1) is over-advanced.",
            likelyCauses: ["Low / dirty oil", "Stuck VVT solenoid", "Timing chain stretch"],
            severity: .serious
        )
    ]

    /// Generic per-prefix fallback when we don't have a curated entry.
    private static func fallback(for code: String) -> DTCExplanation {
        let upper = code.uppercased()
        let prefix = upper.first.map(String.init) ?? "?"

        switch prefix {
        case "P":
            return .init(
                plainEnglish: "Powertrain code — engine, fuel, ignition or transmission related.",
                likelyCauses: ["Sensor or wiring fault", "Mechanical issue in the affected system"],
                severity: .caution
            )
        case "B":
            return .init(
                plainEnglish: "Body code — interior systems like airbags, lights, locks, climate.",
                likelyCauses: ["Sensor or switch", "Module communication"],
                severity: .info
            )
        case "C":
            return .init(
                plainEnglish: "Chassis code — ABS, traction control, steering or suspension.",
                likelyCauses: ["Wheel speed sensor", "ABS module", "Wiring harness"],
                severity: .serious
            )
        case "U":
            return .init(
                plainEnglish: "Network code — modules in the car can't talk to each other properly.",
                likelyCauses: ["CAN bus wiring", "Failing module", "Low battery / bad ground"],
                severity: .serious
            )
        default:
            return .init(
                plainEnglish: "Diagnostic trouble code reported by the ECU.",
                likelyCauses: [],
                severity: .caution
            )
        }
    }
}
