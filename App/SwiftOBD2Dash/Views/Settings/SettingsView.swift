//
//  SettingsView.swift
//  SwiftOBD2Dash
//

import SwiftUI
import SwiftOBD2

struct SettingsView: View {
    @Environment(OBDController.self) private var obd
    @State private var selfTestResult: String?
    @State private var isRunningSelfTest = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Form {
                    connectionSection
                    diagnosticsSection
                    vehicleSection
                    fuelSection
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

            // Manual protocol selection. Most modern cars work with CAN 11/500.
            // Auto-detect is fine on quality adapters but cheap clones often pick wrong.
            Picker("Protocol", selection: Binding(
                get: { obd.preferredProtocol },
                set: { obd.preferredProtocol = $0 }
            )) {
                Text("Auto-detect").tag(PROTOCOL?.none)
                ForEach(PROTOCOL.pickable, id: \.self) { proto in
                    Text(proto.displayName).tag(PROTOCOL?.some(proto))
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

    /// Diagnostics — visible details about the live connection plus a self-test button.
    /// Helps figure out where the chain is broken when the dashboard isn't getting data.
    private var diagnosticsSection: some View {
        Section {
            LabeledContent("Adapter", value: obd.connectedDeviceName ?? "—")
                .listRowBackground(Theme.card)

            LabeledContent("Last reading") {
                Text(lastReadingText)
                    .foregroundStyle(obd.hasLiveData ? Theme.accent : Theme.textSecondary)
            }
            .listRowBackground(Theme.card)

            Button {
                Task {
                    isRunningSelfTest = true
                    selfTestResult = await obd.runSelfTest()
                    isRunningSelfTest = false
                }
            } label: {
                HStack {
                    Text("Run self-test")
                    Spacer()
                    if isRunningSelfTest { ProgressView() }
                }
            }
            .disabled(isRunningSelfTest || !obd.connectionState.isConnected)
            .listRowBackground(Theme.card)

            if let result = selfTestResult {
                Text(result)
                    .font(.callout)
                    .foregroundStyle(result.hasPrefix("OK") ? Theme.accent : Theme.warning)
                    .listRowBackground(Theme.card)
            }
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("Self-test sends a single RPM request and reports the raw outcome. Useful when the dashboard shows 'Connected' but no live data is appearing.")
                .foregroundStyle(Theme.textMuted)
        }
    }

    private var lastReadingText: String {
        guard let last = obd.lastReadingAt else { return "—" }
        let elapsed = Date().timeIntervalSince(last)
        if elapsed < 1.5 { return "Live" }
        if elapsed < 60  { return "\(Int(elapsed)) s ago" }
        return "\(Int(elapsed/60)) min ago"
    }

    /// Fuel computer config — tank size + fuel type. These feed into Range and L/h math.
    private var fuelSection: some View {
        Section {
            Picker("Fuel type", selection: Binding(
                get: { obd.fuel.fuelType },
                set: { obd.fuel.fuelType = $0 }
            )) {
                ForEach(FuelType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .listRowBackground(Theme.card)

            HStack {
                Text("Tank size")
                Spacer()
                TextField("Litres", value: Binding(
                    get: { obd.fuel.tankSizeLitres },
                    set: { obd.fuel.tankSizeLitres = max(1, $0) }
                ), format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                Text("L").foregroundStyle(Theme.textSecondary)
            }
            .listRowBackground(Theme.card)
        } header: {
            Text("Fuel")
        } footer: {
            Text("Range needs MAF + fuel level from your car. If your car doesn't expose either, range will show \"—\". Check your owner's manual for tank size.")
                .foregroundStyle(Theme.textMuted)
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
