//
//  Theme.swift
//  SwiftOBD2Dash
//
//  Dark "instrument cluster" theme. Big numbers, low chrome, glanceable in sunlight.
//

import SwiftUI

enum Theme {
    /// Page background — deep, near-black so the screen disappears at night.
    static let bg            = Color(red: 0.04, green: 0.04, blue: 0.05)

    /// Card / tile background — one notch lighter than the page.
    static let card          = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let cardStroke    = Color.white.opacity(0.06)

    /// Accent — green like a healthy gauge needle.
    static let accent        = Color(red: 0.02, green: 0.81, blue: 0.23)

    /// Warning + critical (yellow → red) for DTC severity, redline, overheat.
    static let warning       = Color(red: 1.00, green: 0.78, blue: 0.10)
    static let critical      = Color(red: 1.00, green: 0.27, blue: 0.27)

    /// Text levels.
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let textMuted     = Color.white.opacity(0.40)
}

// MARK: - Reusable typography

extension Font {
    /// For the giant numbers on the dashboard. Monospaced so they don't twitch.
    static let dashHuge   = Font.system(size: 72, weight: .semibold, design: .rounded).monospacedDigit()
    static let dashLarge  = Font.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit()
    static let dashMedium = Font.system(size: 28, weight: .medium,    design: .rounded).monospacedDigit()
    static let dashLabel  = Font.system(size: 13, weight: .medium,    design: .rounded).smallCaps()
}

// MARK: - Card modifier

struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View { modifier(Card()) }
}
