//
//  OBDController.swift
//  SwiftOBD2Dash
//
//  Thin app-level wrapper around `OBDService` from the SwiftOBD2 package.
//  It owns the connection lifecycle, decides which PIDs to poll, and exposes
//  a single observable surface that views read from.
//

import Foundation
import Combine
import SwiftUI
import SwiftOBD2

@Observable
final class OBDController {

    // MARK: - Public observable state

    /// Live connection state from the underlying service.
    var connectionState: ConnectionState = .disconnected

    /// Last error surfaced to the UI (cleared on next successful action).
    var lastError: String?

    /// The most recent vehicle info returned by `startConnection`.
    var vehicleInfo: OBDInfo?

    /// Whether a connect attempt is in flight.
    var isConnecting: Bool = false

    /// All PID readings the dashboard cares about, keyed by PID.
    var readings: [OBDCommand: MeasurementResult] = [:]

    /// Diagnostics state.
    var dtcs: [ECUID: [TroubleCode]] = [:]
    var lastDTCScan: Date?
    var isScanningDTCs: Bool = false

    /// Last connection mode chosen by the user.
    var connectionType: ConnectionType {
        get { service.connectionType }
        set { service.connectionType = newValue }
    }

    // MARK: - Underlying service

    /// We keep the SwiftOBD2 service private; everything goes through this controller.
    let service = OBDService(connectionType: .bluetooth)

    /// Combine bag for the polling pipeline.
    private var pollCancellable: AnyCancellable?
    private var stateCancellable: AnyCancellable?

    /// Polling modes. The dashboard wants a tight loop on a small set of PIDs;
    /// the Sensors view wants a wider sweep but doesn't need 0.4 s refresh.
    enum PollingMode: Equatable {
        case dashboard
        case wide
    }

    /// Currently active polling mode. Views toggle this via `setPollingMode`.
    var pollingMode: PollingMode = .dashboard

    /// Fuel-consumption calculator. Updated on every successful poll.
    let fuel = FuelComputer()

    /// PIDs the dashboard polls continuously.
    /// MAF + commandedEquivRatio are added so the FuelComputer has what it needs.
    static let dashboardPIDs: [OBDCommand] = [
        .mode1(.rpm),
        .mode1(.speed),
        .mode1(.coolantTemp),
        .mode1(.intakeTemp),
        .mode1(.throttlePos),
        .mode1(.engineLoad),
        .mode1(.fuelLevel),
        .mode1(.controlModuleVoltage),
        .mode1(.maf),
        .mode1(.commandedEquivRatio)
    ]

    /// Wider PID set polled when the Sensors view is on screen.
    /// Built from the curated knowledge base — anything we know how to interpret.
    static let widePIDs: [OBDCommand] = SensorKnowledgeBase.allPIDs

    init() {
        // Mirror the service's @Published connectionState onto our @Observable property.
        stateCancellable = service.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                if state.isConnected == false {
                    self?.stopPolling()
                }
            }
    }

    // MARK: - Connection

    /// Status string suitable for a banner.
    var statusLine: String {
        if isConnecting { return "Connecting…" }
        switch connectionState {
        case .disconnected:        return "Adapter not connected"
        case .connecting:          return "Connecting…"
        case .connectedToAdapter:  return "Adapter found, waiting for car"
        case .connectedToVehicle:  return "Connected"
        case .error:               return "Connection error"
        }
    }

    /// Kick off the full handshake: scan → adapter → vehicle.
    @MainActor
    func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        lastError = nil
        defer { isConnecting = false }

        do {
            // The library auto-scans when no peripheral has been chosen yet.
            // Protocol 6 (CAN 11/500) is the modern default; falls back if not supported.
            let info = try await service.startConnection(preferedProtocol: nil, timeout: 12)
            vehicleInfo = info
            startPolling()
        } catch {
            lastError = friendly(error)
        }
    }

    func disconnect() {
        stopPolling()
        service.stopConnection()
    }

    // MARK: - Polling

    /// Switch polling mode. Restarts the pipeline if we're already connected.
    @MainActor
    func setPollingMode(_ mode: PollingMode) {
        guard mode != pollingMode else { return }
        pollingMode = mode
        if connectionState.isConnected {
            startPolling()
        }
    }

    /// Start the continuous-update pipeline for the active mode's PID set.
    /// PIDs the car doesn't support are filtered out so we don't waste BLE round-trips.
    func startPolling() {
        stopPolling()

        let candidatePIDs: [OBDCommand]
        let interval: TimeInterval

        switch pollingMode {
        case .dashboard:
            candidatePIDs = Self.dashboardPIDs
            interval = 0.4
        case .wide:
            candidatePIDs = Self.widePIDs
            interval = 1.5
        }

        // Filter against what the car actually supports. If the library hasn't
        // populated supportedPIDs yet, ask for everything (optimistic).
        let pids: [OBDCommand]
        if let supported = vehicleInfo?.supportedPIDs, !supported.isEmpty {
            let supportedSet = Set(supported)
            pids = candidatePIDs.filter { supportedSet.contains($0) }
        } else {
            pids = candidatePIDs
        }

        guard !pids.isEmpty else { return }

        pollCancellable = service.startContinuousUpdates(pids, unit: .metric, interval: interval)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.lastError = self?.friendly(error)
                }
            } receiveValue: { [weak self] batch in
                guard let self else { return }
                for (pid, value) in batch {
                    self.readings[pid] = value
                }
                // Recompute fuel metrics with the freshly-merged readings.
                self.fuel.update(readings: self.readings)
            }
    }

    func stopPolling() {
        pollCancellable?.cancel()
        pollCancellable = nil
    }

    // MARK: - Diagnostics

    /// Scan for stored DTCs and refresh `dtcs`.
    @MainActor
    func scanDTCs() async {
        guard !isScanningDTCs else { return }
        isScanningDTCs = true
        lastError = nil
        defer { isScanningDTCs = false }
        do {
            let result = try await service.scanForTroubleCodes()
            dtcs = result
            lastDTCScan = Date()
        } catch {
            lastError = friendly(error)
        }
    }

    /// Clear stored DTCs. The Mil light won't go off until the ECU re-checks readiness.
    @MainActor
    func clearDTCs() async {
        lastError = nil
        do {
            try await service.clearTroubleCodes()
            dtcs = [:]
        } catch {
            lastError = friendly(error)
        }
    }

    // MARK: - Helpers

    /// Quick lookup for a single reading.
    func value(for pid: OBDCommand) -> MeasurementResult? { readings[pid] }

    /// Convenience accessors used by the dashboard tiles.
    var rpm: Double?       { readings[.mode1(.rpm)]?.value }
    var speed: Double?     { readings[.mode1(.speed)]?.value }
    var coolant: Double?   { readings[.mode1(.coolantTemp)]?.value }
    var intake: Double?    { readings[.mode1(.intakeTemp)]?.value }
    var throttle: Double?  { readings[.mode1(.throttlePos)]?.value }
    var load: Double?      { readings[.mode1(.engineLoad)]?.value }
    var fuelLevel: Double? { readings[.mode1(.fuelLevel)]?.value }
    var voltage: Double?   { readings[.mode1(.controlModuleVoltage)]?.value }

    /// Surface library errors as readable strings.
    private func friendly(_ error: Error) -> String {
        if let svc = error as? OBDServiceError {
            switch svc {
            case .noAdapterFound:                return "No OBD-II adapter found. Make sure it's plugged in and in pairing mode."
            case .notConnectedToVehicle:         return "Adapter is connected but the car isn't responding. Turn the key to ON."
            case .adapterConnectionFailed(let underlying): return "Couldn't reach the adapter. (\(underlying.localizedDescription))"
            case .scanFailed(let underlying):    return "Diagnostic scan failed. (\(underlying.localizedDescription))"
            case .clearFailed(let underlying):   return "Couldn't clear codes. (\(underlying.localizedDescription))"
            case .commandFailed(let cmd, let underlying): return "Command \(cmd) failed: \(underlying.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
}
