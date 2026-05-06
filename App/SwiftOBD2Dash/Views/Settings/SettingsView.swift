//
//  SettingsView.swift
//  SwiftOBD2Dash
//

import SwiftUI
import SwiftOBD2

struct SettingsView: View {
    @Environment(OBDController.self) private var obd

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Form {
                    connectionSection
                    vehicleSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
        }
    }

    private var connectionSection: some View {
        Section("Connection") {
            HStack {
                Text("Status")
                Spacer()
                Text(obd.connectionState.description)
                    .foregroundStyle(obd.connectionState.isConnected ? Theme.accent : Theme.textSecondary)
            }
            .listRowBackground(Theme.card)

            Picker("Mode", selection: Binding(
                get: { obd.connectionType },
                set: { obd.connectionType = $0 }
            )) {
                ForEach(ConnectionType.allCases, id: \.self) { ct in
                    Text(ct.rawValue).tag(ct)
                }
            }
            .listRowBackground(Theme.card)

            if obd.connectionState.isConnected {
                Button(role: .destructive) {
                    obd.disconnect()
                } label: {
                    Text("Disconnect")
                }
                .listRowBackground(Theme.card)
            } else {
                Button {
                    Task { await obd.connect() }
                } label: {
                    HStack {
                        Text(obd.isConnecting ? "Connecting…" : "Connect")
                        Spacer()
                        if obd.isConnecting { ProgressView() }
                    }
                }
                .disabled(obd.isConnecting)
                .listRowBackground(Theme.card)
            }

            if let err = obd.lastError {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(Theme.critical)
                    .listRowBackground(Theme.card)
            }
        }
    }

    @ViewBuilder
    private var vehicleSection: some View {
        if let info = obd.vehicleInfo {
            Section("Vehicle") {
                if let vin = info.vin {
                    LabeledContent("VIN", value: vin)
                        .listRowBackground(Theme.card)
                }
                if let proto = info.obdProtocol {
                    LabeledContent("Protocol", value: String(describing: proto))
                        .listRowBackground(Theme.card)
                }
                if let pids = info.supportedPIDs {
                    LabeledContent("Supported PIDs", value: "\(pids.count)")
                        .listRowBackground(Theme.card)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "0.1.0")
                .listRowBackground(Theme.card)
            LabeledContent("Library", value: "SwiftOBD2 (local)")
                .listRowBackground(Theme.card)
            Text("Built for personal use. Free Apple ID signing — re-build from Xcode every 7 days.")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
                .listRowBackground(Theme.card)
        }
    }
}
