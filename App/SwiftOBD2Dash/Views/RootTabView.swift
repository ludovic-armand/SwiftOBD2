//
//  RootTabView.swift
//  SwiftOBD2Dash
//

import SwiftUI

struct RootTabView: View {
    @Environment(OBDController.self) private var obd

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Drive", systemImage: "speedometer") }

            SensorsView()
                .tabItem { Label("Sensors", systemImage: "sensor") }

            DiagnosticsView()
                .tabItem { Label("Diagnostics", systemImage: "stethoscope") }

            TripsView()
                .tabItem { Label("Trips", systemImage: "map") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .background(Theme.bg)
        .overlay(alignment: .top) {
            if !obd.connectionState.isConnected {
                ConnectionBanner()
            }
        }
    }
}

private struct ConnectionBanner: View {
    @Environment(OBDController.self) private var obd
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(obd.isConnecting ? Theme.warning : Theme.critical)
                .frame(width: 8, height: 8)
            Text(obd.statusLine)
                .font(.dashLabel)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
            if !obd.isConnecting {
                Button("Connect") { Task { await obd.connect() } }
                    .font(.dashLabel)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}
