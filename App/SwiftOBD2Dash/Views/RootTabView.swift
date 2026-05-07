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
    }
}
