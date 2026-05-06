//
//  DTCRow.swift
//  SwiftOBD2Dash
//

import SwiftUI
import SwiftOBD2

struct DTCRow: View {
    let troubleCode: TroubleCode
    let ecu: ECUID?

    private var severity: DTCSeverity {
        DTCKnowledge.explanation(for: troubleCode.code).severity
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(severity.color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(troubleCode.code)
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(troubleCode.description)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}
