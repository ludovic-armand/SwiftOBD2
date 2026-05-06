//
//  SensorDetailView.swift
//  SwiftOBD2Dash
//
//  Tap a sensor in the list → see exactly what it measures, the current value
//  with health badge, the normal range, and what high/low readings mean.
//

import SwiftUI
import SwiftOBD2

struct SensorDetailView: View {
    let pid: OBDCommand
    @Environment(OBDController.self) private var obd

    private var knowledge: SensorKnowledge? { SensorKnowledgeBase.entry(for: pid) }
    private var reading: MeasurementResult? { obd.readings[pid] }

    private var health: SensorHealth {
        guard let v = reading?.value, let k = knowledge else { return .unknown }
        return k.evaluate(v)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let k = knowledge {
                    valueHero(k: k)
                    descriptionCard(k: k)
                    if let high = k.highMeans { meaningCard(title: "If it reads high", body: high) }
                    if let low  = k.lowMeans  { meaningCard(title: "If it reads low",  body: low)  }
                } else {
                    Text("No knowledge entry for this sensor yet.")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle(knowledge?.title ?? "Sensor")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pieces

    private func valueHero(k: SensorKnowledge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(k.category.rawValue.uppercased())
                    .font(.dashLabel)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(health.label.uppercased())
                    .font(.dashLabel)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(health.color.opacity(0.18))
                    .foregroundStyle(health.color)
                    .clipShape(Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formattedNumber)
                    .font(.dashHuge)
                    .foregroundStyle(health.color)
                    .contentTransition(.numericText())
                Text(reading?.unit.symbol ?? "")
                    .font(.dashLabel)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(Theme.textMuted)
                Text("Normal: \(k.normalRangeNote)")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func descriptionCard(k: SensorKnowledge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What it measures")
                .font(.dashLabel).foregroundStyle(Theme.textSecondary)
            Text(k.description)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func meaningCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.dashLabel).foregroundStyle(Theme.textSecondary)
            Text(body)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var formattedNumber: String {
        guard let v = reading?.value else { return "—" }
        return v.formatted(.number.precision(.fractionLength(0...2)))
    }
}
