//
//  TripDetailView.swift
//  SwiftOBD2Dash
//

import SwiftUI
import Charts

struct TripDetailView: View {
    let trip: Trip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary
                if !trip.samples.isEmpty {
                    chart(title: "Speed (km/h)", series: trip.samples.map { ($0.timestamp, $0.speedKPH ?? 0) }, color: Theme.accent)
                    chart(title: "RPM",          series: trip.samples.map { ($0.timestamp, $0.rpm ?? 0) },     color: .orange)
                    chart(title: "Coolant (°C)", series: trip.samples.map { ($0.timestamp, $0.coolantC ?? 0) }, color: Theme.warning)
                } else {
                    Text("No samples in this trip.")
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 16)
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle(trip.startedAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .abbreviated

        // Fuel economy for this trip (only meaningful past 100m and if MAF was available).
        let economy: String? = {
            guard trip.distanceKm > 0.1, trip.fuelUsedL > 0 else { return nil }
            let lp100 = (trip.fuelUsedL * 100.0) / trip.distanceKm
            return lp100.formatted(.number.precision(.fractionLength(1))) + " L/100km"
        }()

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                stat(title: "Duration", value: f.string(from: trip.duration) ?? "—")
                stat(title: "Distance", value: trip.distanceKm > 0
                     ? "\(trip.distanceKm.formatted(.number.precision(.fractionLength(1)))) km"
                     : "—")
            }
            HStack(spacing: 12) {
                stat(title: "Top speed", value: "\(Int(trip.maxSpeedKPH)) km/h")
                stat(title: "Avg speed", value: "\(Int(trip.avgSpeedKPH)) km/h")
            }
            HStack(spacing: 12) {
                stat(title: "Fuel used", value: trip.fuelUsedL > 0
                     ? "\(trip.fuelUsedL.formatted(.number.precision(.fractionLength(2)))) L"
                     : "—")
                stat(title: "Economy",   value: economy ?? "—")
            }
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.dashLabel).foregroundStyle(Theme.textSecondary)
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func chart(title: String, series: [(Date, Double)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.dashLabel).foregroundStyle(Theme.textSecondary)
            Chart {
                ForEach(Array(series.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Time", point.0),
                        y: .value(title, point.1)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 140)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
