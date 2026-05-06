//
//  Trip.swift
//  SwiftOBD2Dash
//
//  SwiftData models for trip history.
//

import Foundation
import SwiftData

@Model
final class Trip {
    /// When the trip started.
    var startedAt: Date
    /// When the trip ended. nil while in-progress.
    var endedAt: Date?

    /// Cached aggregates so the trips list doesn't have to load every sample.
    var maxRPM: Double = 0
    var maxSpeedKPH: Double = 0
    var avgSpeedKPH: Double = 0
    var maxCoolantC: Double = 0
    var sampleCount: Int = 0

    /// Optional trip note the user can add later.
    var note: String?

    /// All telemetry samples, owned by this trip.
    @Relationship(deleteRule: .cascade, inverse: \TripSample.trip)
    var samples: [TripSample] = []

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
    }

    /// Computed duration; works during or after the trip.
    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }
}

@Model
final class TripSample {
    var timestamp: Date
    var rpm: Double?
    var speedKPH: Double?
    var coolantC: Double?
    var throttlePct: Double?
    var loadPct: Double?
    var voltage: Double?

    /// Back-reference to the trip; set automatically by the relationship.
    var trip: Trip?

    init(timestamp: Date = .now,
         rpm: Double? = nil,
         speedKPH: Double? = nil,
         coolantC: Double? = nil,
         throttlePct: Double? = nil,
         loadPct: Double? = nil,
         voltage: Double? = nil) {
        self.timestamp = timestamp
        self.rpm = rpm
        self.speedKPH = speedKPH
        self.coolantC = coolantC
        self.throttlePct = throttlePct
        self.loadPct = loadPct
        self.voltage = voltage
    }
}
