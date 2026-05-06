//
//  GaugeTile.swift
//  SwiftOBD2Dash
//
//  A glanceable readout: small label, big number, unit. Optional bar fill
//  underneath for percent-style values (throttle, fuel level, load).
//

import SwiftUI

struct GaugeTile: View {
    let label: String
    let value: Double?
    let unit: String

    /// If both min/max provided, draws a fill bar at the bottom.
    var min: Double = 0
    var max: Double? = nil

    /// Visual treatment swap when value crosses warning / danger thresholds.
    var warnAbove: Double? = nil
    var dangerAbove: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.dashLabel)
                .foregroundStyle(Theme.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formattedValue)
                    .font(.dashLarge)
                    .foregroundStyle(numberColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(unit)
                    .font(.dashLabel)
                    .foregroundStyle(Theme.textMuted)
            }

            if let max, let value {
                ProgressView(value: clamp(value, min: min, max: max), total: max - min)
                    .progressViewStyle(.linear)
                    .tint(numberColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var formattedValue: String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private var numberColor: Color {
        guard let value else { return Theme.textMuted }
        if let dangerAbove, value >= dangerAbove { return Theme.critical }
        if let warnAbove,   value >= warnAbove   { return Theme.warning }
        return Theme.textPrimary
    }

    private func clamp(_ v: Double, min lo: Double, max hi: Double) -> Double {
        Swift.max(0, Swift.min(hi - lo, v - lo))
    }
}
