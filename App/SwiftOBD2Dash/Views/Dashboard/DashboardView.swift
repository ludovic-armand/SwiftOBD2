//
//  DashboardView.swift
//  SwiftOBD2Dash
//
//  Big-glance live readouts. Designed for an iPhone in landscape on a car mount,
//  but works fine in portrait too.
//

import SwiftUI
import SwiftOBD2

struct DashboardView: View {
    @Environment(OBDController.self) private var obd

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.bg.ignoresSafeArea()
                if geo.size.width > geo.size.height {
                    landscape
                } else {
                    portrait
                }
            }
        }
    }

    // MARK: - Layouts

    private var portrait: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Big speed up top.
                speedHero

                // Tach in the middle.
                RPMArc(rpm: obd.rpm ?? 0)
                    .frame(height: 280)
                    .cardStyle()

                // Fuel strip — instant / avg / range.
                fuelStrip

                // Tile grid.
                tileGrid
            }
            .padding(16)
            .padding(.top, 40)   // leave room for the connection banner
        }
    }

    private var landscape: some View {
        HStack(spacing: 16) {
            // Left half: tach.
            RPMArc(rpm: obd.rpm ?? 0)
                .padding(20)
                .cardStyle()
                .frame(maxWidth: .infinity)

            VStack(spacing: 16) {
                speedHero
                fuelStrip
                tileGrid
            }
        }
        .padding(16)
        .padding(.top, 40)
    }

    // MARK: - Pieces

    private var speedHero: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(obd.speed.map { Int($0).description } ?? "—")
                .font(.dashHuge)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
            Text("km/h")
                .font(.dashLabel)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Three-up strip of fuel-related figures. Lays out in a row on wide screens,
    /// wraps to a 2-col grid on tight ones.
    private var fuelStrip: some View {
        HStack(spacing: 12) {
            FuelTile(
                label: "Instant",
                primary: instantPrimary,
                secondary: instantSecondary
            )
            FuelTile(
                label: "Avg",
                primary: obd.fuel.tripAvgLPer100km.map { "\($0.formatted(.number.precision(.fractionLength(1))))" } ?? "—",
                secondary: "L/100km"
            )
            FuelTile(
                label: "Range",
                primary: obd.fuel.rangeKm.map { "\(Int($0))" } ?? "—",
                secondary: "km"
            )
        }
    }

    /// Show L/100km when actually moving; fall back to L/h at idle / red-light stops.
    private var instantPrimary: String {
        if let lp100 = obd.fuel.instantLPer100km {
            return lp100.formatted(.number.precision(.fractionLength(1)))
        }
        if let lph = obd.fuel.instantLPerHour {
            return lph.formatted(.number.precision(.fractionLength(1)))
        }
        return "—"
    }
    private var instantSecondary: String {
        if obd.fuel.instantLPer100km != nil { return "L/100km" }
        if obd.fuel.instantLPerHour   != nil { return "L/h (idle)" }
        return obd.fuel.hasFuelData ? "—" : "no MAF"
    }

    private var tileGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)], spacing: 16) {
            GaugeTile(
                label: "Coolant",
                value: obd.coolant,
                unit: "°C",
                max: 130,
                warnAbove: 105,
                dangerAbove: 115
            )
            GaugeTile(
                label: "Intake air",
                value: obd.intake,
                unit: "°C",
                max: 80
            )
            GaugeTile(
                label: "Throttle",
                value: obd.throttle,
                unit: "%",
                max: 100
            )
            GaugeTile(
                label: "Engine load",
                value: obd.load,
                unit: "%",
                max: 100,
                warnAbove: 85
            )
            GaugeTile(
                label: "Battery",
                value: obd.voltage,
                unit: "V",
                min: 10, max: 16,
                warnAbove: 15.0
            )
        }
    }
}

#Preview {
    DashboardView()
        .environment(OBDController())
        .preferredColorScheme(.dark)
}
