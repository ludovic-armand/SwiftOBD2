//
//  TripsView.swift
//  SwiftOBD2Dash
//

import SwiftUI
import SwiftData

struct TripsView: View {
    @Query(sort: \Trip.startedAt, order: .reverse) private var trips: [Trip]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if trips.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(trips) { trip in
                            NavigationLink(value: trip) {
                                TripRow(trip: trip)
                            }
                            .listRowBackground(Theme.card)
                        }
                        .onDelete(perform: delete)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Trips")
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textMuted)
            Text("No trips yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Trips start recording automatically when the engine is running and the adapter is connected.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { modelContext.delete(trips[i]) }
        try? modelContext.save()
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(durationString)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(trip.maxSpeedKPH)) km/h")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Text("\(Int(trip.maxRPM)) max RPM")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(.vertical, 4)
    }

    private var durationString: String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .abbreviated
        return f.string(from: trip.duration) ?? "—"
    }
}
