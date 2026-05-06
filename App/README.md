# SwiftOBD2 Dash

An always-on iPhone dashboard that talks to a Bluetooth ELM327 / OBD-II adapter and shows live data, diagnostics, and trip history. Built on top of the [SwiftOBD2](../) library that lives in the parent folder.

## Status

Phase 1 (MVP) — done:

- Live dashboard: speed, RPM (animated arc), coolant, intake air, throttle, engine load, fuel level, battery voltage.
- **Sensors tab**: every sensor your car reports (~30 PIDs, filtered to what your specific vehicle actually answers), grouped by system (engine / fuel / air / ignition / emissions / oxygen / electrical / info). Each sensor has a live value, a Normal / Watch / Concerning / Critical health badge, plain-English description of what it measures, normal range, and what it means if the reading is high or low.
- Diagnostics: scan / clear DTCs, plain-English explanations and severity for the most common codes.
- Trips: auto-records when the engine is running; speed / RPM / coolant charts per trip.
- Two-mode polling: 0.4s tight loop on the Drive tab (8 PIDs), 1.5s wide sweep on the Sensors tab (~30 PIDs). The dashboard stays smooth and the BLE link doesn't get overwhelmed.
- Free Apple ID friendly (no paid Developer account needed for personal use).

Phase 2 — not yet built:

- GPS + offline OSM map (MapLibre Native).
- Trip route on map, GPS-corrected speed, region downloads.
- Background trip logging while screen is off.

## Requirements

- macOS with Xcode 15.4+ (Xcode 16 recommended).
- An iPhone (iPhone 12 is fine — iOS 17 or 18).
- A Bluetooth ELM327 OBD-II adapter (BLE, not classic Bluetooth — see the parent library's tested-adapters list).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed.

## First-time setup

1. **Install XcodeGen** (one time, on your Mac):

   ```bash
   brew install xcodegen
   ```

2. **Generate the Xcode project**:

   ```bash
   cd App
   xcodegen
   ```

   This creates `App/SwiftOBD2Dash.xcodeproj` from `project.yml`. Don't commit the `.xcodeproj` — regenerate it any time.

3. **Open in Xcode**:

   ```bash
   open SwiftOBD2Dash.xcodeproj
   ```

4. **Pick your signing team**:
   - Select the `SwiftOBD2Dash` target → Signing & Capabilities.
   - Team → "Add an Account…" → sign in with your free Apple ID → pick your "Personal Team".
   - You may need to change the bundle identifier if `com.ludovic.swiftobd2dash` clashes — anything unique works.

5. **Build to your iPhone**:
   - Plug the iPhone in via USB.
   - Trust the computer on the phone.
   - Pick the iPhone as the run destination at the top of Xcode.
   - Hit ⌘R.
   - First launch on the phone: Settings → General → VPN & Device Management → trust your developer profile.

## The 7-day cert problem

Free Apple ID signing expires the app after **7 days**. To "re-up" it:

1. Plug the phone into the Mac.
2. Open the project in Xcode.
3. ⌘R to re-build and re-install.

That's it — the app data (saved trips, settings) survives because the bundle ID stays the same.

If that's too annoying for an "always in the car" device, the alternatives are:

- **Apple Developer Program ($99/yr):** signs for a year, install via TestFlight, no monthly babysitting.
- **AltStore / SideStore:** automatically re-signs with your free Apple ID over Wi-Fi every 7 days. Works but requires a Mac/PC at home left running.

## Pairing the adapter

ELM327 BLE adapters mostly auto-pair when iOS sees them. Workflow:

1. Plug the adapter into the OBD-II port (under the dash).
2. Turn the key to ON (engine doesn't have to be running for pairing, but it does for live data).
3. Open the app → Settings → tap **Connect**.
4. The library scans for known ELM327 services and connects to the first match.

If nothing happens, double-check Bluetooth permission and the adapter's status LED.

## Folder layout

```
App/
├── project.yml                  # XcodeGen spec
└── SwiftOBD2Dash/
    ├── SwiftOBD2DashApp.swift   # @main, sets up SwiftData container + OBDController
    ├── Models/
    │   └── Trip.swift           # SwiftData: Trip + TripSample
    ├── Services/
    │   ├── OBDController.swift  # Wraps OBDService, exposes @Observable surface
    │   ├── TripRecorder.swift   # Auto-records trips when engine is running
    │   └── DTCKnowledge.swift   # Plain-English DTC explanations
    ├── Theme/
    │   └── Theme.swift          # Colors, fonts, card style
    ├── Views/
    │   ├── RootTabView.swift
    │   ├── Dashboard/           # Live readouts
    │   ├── Diagnostics/         # DTCs
    │   ├── Trips/               # Trip history + charts
    │   └── Settings/
    └── Resources/
        └── Assets.xcassets/
```

## Phase 2 roadmap

When ready to add maps:

1. Add **MapLibre Native iOS** as a Swift Package: `https://github.com/maplibre/maplibre-gl-native-distribution`.
2. New `MapView.swift` wrapping `MGLMapView` via `UIViewRepresentable`.
3. New tab "Map" alongside Drive / Diagnostics / Trips.
4. Background location permission flow (the Info.plist entries are already there).
5. Region download UI (download a bbox of OSM tiles for the user's home area + travel destinations).
6. Persist GPS samples on `TripSample` (lat / lon / heading) — schema migration via SwiftData.

## Common problems

- **"No adapter found"**: the cheap ELM327 clones often advertise non-standard service UUIDs. The library auto-detects most of them but not all. If yours doesn't connect, we'll need to add its UUID — capture it with [LightBlue](https://apps.apple.com/us/app/lightblue/id557428110) and tell me.
- **Blank dashboard but adapter shows connected**: car key isn't on, or the car uses a non-standard protocol the library hasn't auto-detected. Try setting `preferedProtocol` in `OBDController.connect()`.
- **App stops working after a week**: that's the 7-day free-cert thing. Plug into Xcode and re-run.

## License

App code: MIT (matching the underlying SwiftOBD2 library).
