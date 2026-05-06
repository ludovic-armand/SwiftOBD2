//
//  RPMArc.swift
//  SwiftOBD2Dash
//
//  A circular tach-style gauge. Drawn with Canvas so it stays smooth at any
//  size and doesn't allocate views for each tick.
//

import SwiftUI

struct RPMArc: View {
    let rpm: Double
    /// Where the redline sits, in RPM.
    var redline: Double = 6500
    /// Top end of the dial (a bit beyond redline so the needle doesn't slam).
    var maxRPM: Double = 8000

    private let startAngle: Angle = .degrees(135)
    private let endAngle:   Angle = .degrees(45)   // wraps through 360°

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth = size * 0.08
            let radius = (size - lineWidth) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Track.
                arc(from: startAngle, to: endAngle, radius: radius, lineWidth: lineWidth, in: center)
                    .stroke(Theme.cardStroke, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Filled portion up to current rpm.
                let progress = max(0, min(1, rpm / maxRPM))
                let sweep = sweepAngle(for: progress)
                arc(from: startAngle, to: sweep, radius: radius, lineWidth: lineWidth, in: center)
                    .stroke(needleColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .animation(.easeOut(duration: 0.15), value: rpm)

                // Tick marks every 1000 RPM.
                ticks(radius: radius, in: center)

                // Big number.
                VStack(spacing: 2) {
                    Text(rpm > 0 ? rpm.formatted(.number.precision(.fractionLength(0))) : "—")
                        .font(.dashHuge)
                        .foregroundStyle(needleColor)
                        .contentTransition(.numericText())
                    Text("RPM")
                        .font(.dashLabel)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var needleColor: Color {
        if rpm >= redline { return Theme.critical }
        if rpm >= redline - 1000 { return Theme.warning }
        return Theme.accent
    }

    private func sweepAngle(for progress: Double) -> Angle {
        // Total sweep is 270°.
        .degrees(135 + progress * 270)
    }

    private func arc(from a1: Angle, to a2: Angle, radius: CGFloat, lineWidth: CGFloat, in center: CGPoint) -> Path {
        var p = Path()
        p.addArc(center: center, radius: radius, startAngle: a1, endAngle: a2, clockwise: false)
        return p
    }

    private func ticks(radius: CGFloat, in center: CGPoint) -> some View {
        // Tick marks drawn as line segments between two radii, placed by trig.
        // Doing this in Canvas avoids the SwiftUI modifier-order pitfalls of
        // rotating + offsetting + positioning a Rectangle.
        Canvas { context, _ in
            for stop in stride(from: 0.0, through: maxRPM, by: 1000) {
                let progress = stop / maxRPM
                let angleRad = (135.0 + progress * 270.0) * .pi / 180.0
                let inner = CGPoint(
                    x: center.x + cos(angleRad) * (radius - 6),
                    y: center.y + sin(angleRad) * (radius - 6)
                )
                let outer = CGPoint(
                    x: center.x + cos(angleRad) * (radius + 6),
                    y: center.y + sin(angleRad) * (radius + 6)
                )
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                let isRedline = stop >= redline
                context.stroke(
                    path,
                    with: .color(isRedline ? Theme.critical : Theme.textMuted),
                    lineWidth: 2
                )
            }
        }
    }
}
