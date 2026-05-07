//
//  ConnectionStatusCard.swift
//  SwiftOBD2Dash
//
//  Compact status pill at the top of the Drive tab. Single line: state dot +
//  short label + adapter / freshness, plus Connect or Retry button when needed.
//  Detailed info (protocol, supported-PID count, etc.) lives in Settings —
//  the homepage just needs glanceable.
//

import SwiftUI
import SwiftOBD2

struct ConnectionStatusCard: View {
    @Environment(OBDController.self) private var obd

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let s = currentStatus(now: now)

        HStack(spacing: 10) {
            StatusDot(color: s.color, pulsing: s.pulsing)

            Text(s.headline)
                .font(.callout.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            if let detail = s.detail {
                Text("·")
                    .foregroundStyle(Theme.textMuted)
                Text(detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            actionButton(for: s.kind)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.card)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: 1))
    }

    // MARK: - Action button

    @ViewBuilder
    private func actionButton(for kind: StatusKind) -> some View {
        switch kind {
        case .disconnected:
            Button("Connect") { Task { await obd.connect() } }
                .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.mini)
                .disabled(obd.isConnecting)
        case .connecting:
            ProgressView().controlSize(.mini).tint(Theme.warning)
        case .adapterOnly, .stalled:
            Button("Retry") { Task { await obd.connect() } }
                .buttonStyle(.bordered).tint(Theme.warning).controlSize(.mini)
        case .fullyConnected:
            EmptyView()
        }
    }

    // MARK: - Status derivation

    private enum StatusKind { case disconnected, connecting, adapterOnly, fullyConnected, stalled }

    private struct Status {
        let kind: StatusKind
        let color: Color
        let pulsing: Bool
        let headline: String
        let detail: String?
    }

    private func currentStatus(now: Date) -> Status {
        if obd.isConnecting {
            return Status(kind: .connecting, color: Theme.warning, pulsing: true,
                          headline: "Connecting…", detail: nil)
        }

        switch obd.connectionState {
        case .disconnected, .error:
            return Status(kind: .disconnected, color: Theme.critical, pulsing: false,
                          headline: "Not connected", detail: nil)

        case .connecting:
            return Status(kind: .connecting, color: Theme.warning, pulsing: true,
                          headline: "Connecting…", detail: nil)

        case .connectedToAdapter:
            return Status(kind: .adapterOnly, color: .orange, pulsing: true,
                          headline: "Paired, car silent",
                          detail: obd.connectedDeviceName)

        case .connectedToVehicle:
            if let last = obd.lastReadingAt {
                let elapsed = now.timeIntervalSince(last)
                if elapsed > 5 {
                    return Status(kind: .stalled, color: Theme.critical, pulsing: true,
                                  headline: "Stalled \(Int(elapsed)) s",
                                  detail: obd.connectedDeviceName)
                }
                return Status(kind: .fullyConnected, color: Theme.accent, pulsing: false,
                              headline: "Live",
                              detail: detailString(elapsed: elapsed))
            } else {
                return Status(kind: .adapterOnly, color: Theme.warning, pulsing: true,
                              headline: "Waiting for first reading…",
                              detail: obd.connectedDeviceName)
            }
        }
    }

    private func detailString(elapsed: TimeInterval) -> String {
        let name = obd.connectedDeviceName ?? "OBD-II"
        if elapsed < 1.5 { return name }
        return "\(name) · \(Int(elapsed)) s ago"
    }
}

// MARK: - Status dot

private struct StatusDot: View {
    let color: Color
    let pulsing: Bool

    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .onAppear { applyPulse(pulsing) }
            .onChange(of: pulsing) { _, isPulsing in applyPulse(isPulsing) }
    }

    private func applyPulse(_ on: Bool) {
        if on {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                scale = 1.45
            }
        } else {
            withAnimation { scale = 1.0 }
        }
    }
}
