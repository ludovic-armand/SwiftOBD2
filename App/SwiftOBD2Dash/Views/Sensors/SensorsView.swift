//
//  SensorsView.swift
//  SwiftOBD2Dash
//
//  The "all sensors" view. Lists every PID the car supports that we have
//  knowledge for, grouped by system. Each row shows the live value plus a
//  Normal / Watch / Concerning / Critical badge. Tapping opens the detail.
//

import SwiftUI
import SwiftOBD2

struct SensorsView: View {
    @Environment(OBDController.self) private var obd

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if !obd.connectionState.isConnected {
                    notConnectedState
                } else if visibleEntries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Sensors")
            .navigationDestination(for: SensorRowItem.self) { item in
                SensorDetailView(pid: item.pid)
            }
        }
        .onAppear  { obd.setPollingMode(.wide) }
        .onDisappear { obd.setPollingMode(.dashboard) }
    }

    // MARK: - Subviews

    private var list: some View {
        List {
            ForEach(SensorCategory.allCases) { category in
                let entries = visibleEntries.filter { $0.knowledge.category == category }
                if !entries.isEmpty {
                    Section {
                        ForEach(entries) { item in
                            NavigationLink(value: item) {
                                SensorRow(item: item, reading: obd.readings[item.pid])
                            }
                            .listRowBackground(Theme.card)
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.systemImage)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            Section {
                Text("Updated every 1.5s while this tab is open. Sensors your car doesn't report are hidden.")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textMuted)
            Text("Waiting for sensor list…")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("The car hasn't told us which sensors it supports yet. Wait a few seconds after connecting.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var notConnectedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textMuted)
            Text("Adapter not connected")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Button("Connect") { Task { await obd.connect() } }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
    }

    // MARK: - Filtering

    /// PIDs we know about, that the car supports (or all if support list isn't known yet).
    private var visibleEntries: [SensorRowItem] {
        let supportedSet: Set<OBDCommand>? = obd.vehicleInfo?.supportedPIDs.map(Set.init)
        return SensorKnowledgeBase.allPIDs
            .compactMap { pid -> SensorRowItem? in
                guard let knowledge = SensorKnowledgeBase.entry(for: pid) else { return nil }
                if let s = supportedSet, !s.contains(pid) { return nil }
                return SensorRowItem(pid: pid, knowledge: knowledge)
            }
            .sorted { $0.knowledge.title < $1.knowledge.title }
    }
}

// MARK: - Row item (Hashable so it can drive NavigationLink(value:))

struct SensorRowItem: Hashable, Identifiable {
    let pid: OBDCommand
    let knowledge: SensorKnowledge

    var id: OBDCommand { pid }

    static func == (lhs: SensorRowItem, rhs: SensorRowItem) -> Bool {
        lhs.pid == rhs.pid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }
}

// MARK: - Row

private struct SensorRow: View {
    let item: SensorRowItem
    let reading: MeasurementResult?

    private var health: SensorHealth {
        guard let v = reading?.value else { return .unknown }
        return item.knowledge.evaluate(v)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(health.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.knowledge.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(item.knowledge.normalRangeNote)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatted)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(health.label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(health.color)
            }
        }
        .padding(.vertical, 4)
    }

    private var formatted: String {
        guard let r = reading else { return "—" }
        let n = r.value.formatted(.number.precision(.fractionLength(0...2)))
        return "\(n) \(r.unit.symbol)"
    }
}
