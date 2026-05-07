//
//  Protocol+DisplayName.swift
//  SwiftOBD2Dash
//
//  Friendly names for the SwiftOBD2 PROTOCOL enum so the picker in Settings
//  doesn't show "protocol6" — it shows "CAN 11-bit, 500 kbps".
//

import Foundation
import SwiftOBD2

extension PROTOCOL {
    /// Long, descriptive name for the picker.
    var displayName: String {
        switch self {
        case .protocol1: return "SAE J1850 PWM (Ford pre-2008)"
        case .protocol2: return "SAE J1850 VPW (GM pre-2008)"
        case .protocol3: return "ISO 9141-2 (Asian / EU pre-2004)"
        case .protocol4: return "ISO 14230-4 KWP (5-baud init)"
        case .protocol5: return "ISO 14230-4 KWP (fast init)"
        case .protocol6: return "CAN 11-bit, 500 kbps  ← most modern cars"
        case .protocol7: return "CAN 29-bit, 500 kbps"
        case .protocol8: return "CAN 11-bit, 250 kbps"
        case .protocol9: return "CAN 29-bit, 250 kbps"
        case .protocolA: return "SAE J1939 (heavy-duty trucks)"
        case .protocolB: return "USER1 CAN"
        case .protocolC: return "USER2 CAN"
        case .NONE:      return "None"
        }
    }

    /// Short tag for compact UI.
    var shortName: String {
        switch self {
        case .protocol1: return "J1850 PWM"
        case .protocol2: return "J1850 VPW"
        case .protocol3: return "ISO 9141-2"
        case .protocol4: return "KWP slow"
        case .protocol5: return "KWP fast"
        case .protocol6: return "CAN 11/500"
        case .protocol7: return "CAN 29/500"
        case .protocol8: return "CAN 11/250"
        case .protocol9: return "CAN 29/250"
        case .protocolA: return "J1939"
        case .protocolB: return "USER1"
        case .protocolC: return "USER2"
        case .NONE:      return "None"
        }
    }

    /// The protocols worth offering in a user-facing picker. Drops NONE and
    /// the USER slots; J1939 is rare enough that we still keep it for trucks.
    static var pickable: [PROTOCOL] {
        [.protocol6, .protocol7, .protocol8, .protocol9,
         .protocol3, .protocol4, .protocol5,
         .protocol1, .protocol2,
         .protocolA]
    }
}
