//
//  SwiftOBD2DashApp.swift
//  SwiftOBD2Dash
//
//  Always-on dashboard for an iPhone 12 left in the car.
//

import SwiftUI
import SwiftData

@main
struct SwiftOBD2DashApp: App {
    /// Single shared OBD controller for the whole app.
    @State private var obd = OBDController()

    var body: some Scene {
        WindowGroup {
            ContentRoot()
                .environment(obd)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onAppear {
                    // Keep the screen on while the app is in front. This is a dashboard.
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
        .modelContainer(for: [Trip.self, TripSample.self])
    }
}

/// Owns the trip recorder. It can only be built once the modelContext is in the environment,
/// which is why we build it here rather than in the `App` itself.
private struct ContentRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(OBDController.self) private var obd

    @State private var recorder: TripRecorder?

    var body: some View {
        RootTabView()
            .environment(\.tripRecorder, recorder)
            .onAppear {
                if recorder == nil {
                    recorder = TripRecorder(modelContext: modelContext, obd: obd)
                }
            }
            .onChange(of: obd.connectionState.isConnected, initial: false) { _, connected in
                guard let recorder else { return }
                if connected {
                    recorder.start()
                } else {
                    recorder.stop()
                }
            }
    }
}
