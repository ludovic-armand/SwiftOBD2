//
//  FuelTile.swift
//  SwiftOBD2Dash
//
//  Compact tile used by the dashboard's fuel strip — three of these sit in a row
//  showing instant consumption, trip average, and remaining range.
//

import SwiftUI

struct FuelTile: View {
    let label: String
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.dashLabel)
                .foregroundStyle(Theme.textSecondary)

            Text(primary)
                .font(.dashMedium)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())

            Text(secondary)
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.cardStroke, lineWidth: 1)
        )
    }
}
