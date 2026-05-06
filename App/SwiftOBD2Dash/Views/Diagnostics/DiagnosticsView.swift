//
//  DiagnosticsView.swift
//  SwiftOBD2Dash
//

import SwiftUI
import SwiftOBD2

struct DiagnosticsView: View {
    @Environment(OBDController.self) private var obd
    @State private var confirmingClear = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                content
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await obd.scanDTCs() }
                    } label: {
                        if obd.isScanningDTCs {
                            ProgressView()
                        } else {
                            Label("Scan", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(!obd.connectionState.isConnected || obd.isScanningDTCs)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if obd.dtcs.isEmpty {
            emptyState
        } else {
            dtcList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(obd.lastDTCScan == nil ? Theme.textMuted : Theme.accent)

            Text(obd.lastDTCScan == nil ? "No scan yet" : "No trouble codes 🎉")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text(obd.lastDTCScan == nil
                 ? "Connect to your car and tap Scan to read stored codes."
                 : "Last scanned \(obd.lastDTCScan!.formatted(.relative(presentation: .named))).")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !obd.connectionState.isConnected {
                Text("Adapter not connected")
                    .font(.dashLabel)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.critical.opacity(0.15))
                    .foregroundStyle(Theme.critical)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dtcList: some View {
        List {
            Section {
                ForEach(flattened, id: \.code) { item in
                    NavigationLink(value: item) {
                        DTCRow(troubleCode: item, ecu: nil)
                    }
                    .listRowBackground(Theme.card)
                }
            } header: {
                Text("\(flattened.count) trouble code\(flattened.count == 1 ? "" : "s")")
                    .foregroundStyle(Theme.textSecondary)
            }

            Section {
                Button(role: .destructive) {
                    confirmingClear = true
                } label: {
                    Label("Clear codes", systemImage: "trash")
                }
                .listRowBackground(Theme.card)
            } footer: {
                Text("Clearing only resets the stored codes. The check-engine light returns if the underlying problem is still present.")
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationDestination(for: TroubleCode.self) { code in
            DTCDetailView(code: code)
        }
        .confirmationDialog("Clear all stored codes?",
                            isPresented: $confirmingClear,
                            titleVisibility: .visible) {
            Button("Clear", role: .destructive) {
                Task { await obd.clearDTCs() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Flattens the per-ECU dictionary into a single sorted list.
    private var flattened: [TroubleCode] {
        obd.dtcs.values.flatMap { $0 }.sorted()
    }
}

struct DTCDetailView: View {
    let code: TroubleCode

    private var explanation: DTCExplanation { DTCKnowledge.explanation(for: code.code) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(code.code)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    severityBadge
                }

                Text(code.description)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(explanation.plainEnglish)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)

                if !explanation.likelyCauses.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Most common causes")
                            .font(.dashLabel).foregroundStyle(Theme.textSecondary)
                        ForEach(explanation.likelyCauses, id: \.self) { cause in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.top, 7)
                                Text(cause).foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var severityBadge: some View {
        Text(explanation.severity.label.uppercased())
            .font(.dashLabel)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(explanation.severity.color.opacity(0.18))
            .foregroundStyle(explanation.severity.color)
            .clipShape(Capsule())
    }
}
