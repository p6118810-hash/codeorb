//
//  NotchHeaderView.swift
//  CodeOrb
//
//  Header bar for the dynamic island
//

import SwiftUI

enum AgentMascotKind {
    case solarSystem
    case codex
}

struct AgentMascotIcon: View {
    let kind: AgentMascotKind
    let size: CGFloat
    var animate: Bool = false
    var planetProviders: [SessionProviderKind] = []

    var body: some View {
        switch kind {
        case .solarSystem:
            CodeOrbSolarSystemIcon(
                size: size,
                planetProviders: planetProviders,
                animateOrbit: animate
            )
        case .codex:
            CodexGlyphIcon(size: size, animateGlow: animate)
        }
    }
}

struct CodeOrbSolarSystemIcon: View {
    let size: CGFloat
    let planetProviders: [SessionProviderKind]
    var animateOrbit: Bool = false

    @State private var orbitEntryStart = Date()

    init(
        size: CGFloat = 16,
        planetProviders: [SessionProviderKind] = [],
        animateOrbit: Bool = false
    ) {
        self.size = size
        self.planetProviders = planetProviders
        self.animateOrbit = animateOrbit
    }

    var body: some View {
        Group {
            if animateOrbit {
                TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    solarSystemBody(time: t, pulseScale: 0.98 + 0.05 * CGFloat((sin(t * 4.0) + 1) * 0.5))
                }
            } else {
                solarSystemBody(time: 0, pulseScale: 1.0)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            orbitEntryStart = .now
        }
        .onChange(of: providerSignature) { _, _ in
            orbitEntryStart = .now
        }
    }

    @ViewBuilder
    private func solarSystemBody(time: TimeInterval, pulseScale: CGFloat) -> some View {
        let orbitingProviders = Array(planetProviders.prefix(8))
        let sunSize = size * 0.2
        let innerGlowSize = size * 1.02
        let halfCanvas = size * 0.5
        let totalOrbitSlots = 8
        // Real solar-system semimajor axes in AU, compressed with a log scale so
        // Mercury is not glued to the sun while Neptune still fits the icon.
        let orbitalDistancesAU: [CGFloat] = [0.39, 0.72, 1.0, 1.52, 5.20, 9.58, 19.2, 30.05]
        let planetSize = size * 0.1
        let planetSizes: [CGFloat] = Array(repeating: planetSize, count: totalOrbitSlots)
        let outerEdgePadding = size * 0.01
        let innerOrbitGap = size * 0.07
        let minRadius = (sunSize * 0.5) + (planetSizes[0] * 0.5) + innerOrbitGap
        let maxRadius = halfCanvas - (planetSizes.max() ?? 0) * 0.5 - outerEdgePadding
        let canonicalOrbitRadii = scaledOrbitRadii(
            distancesAU: orbitalDistancesAU,
            minRadius: minRadius,
            maxRadius: max(maxRadius, minRadius + size * 0.12)
        )
        let activeOrbitIndices = distributedOrbitIndices(
            activeCount: orbitingProviders.count,
            totalSlots: totalOrbitSlots
        )
        let phaseOffsets: [Double] = [-118, 16, 132, 208, 278, 338, 62, 168]
        let orbitSpeeds: [Double] = [132, 110, 92, 78, 62, 52, 44, 38]
        let sunCore = Color(red: 1.0, green: 0.78, blue: 0.28)
        let sunEdge = Color(red: 1.0, green: 0.48, blue: 0.16)
        let introProgress = orbitIntroProgress(at: time)
        let introOpacity = max(0.0, min(1.0, Double(introProgress * 1.35)))
        let orbitStrokeColor = Color.white.opacity(0.045)

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            sunEdge.opacity(0.22),
                            sunEdge.opacity(0.04),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.68
                    )
                )
                .frame(width: innerGlowSize, height: innerGlowSize)
                .blur(radius: size * 0.08)

            if !orbitingProviders.isEmpty {
                ForEach(Array(canonicalOrbitRadii.enumerated()), id: \.offset) { index, radius in
                    Circle()
                        .stroke(
                            orbitStrokeColor,
                            lineWidth: max(0.25, size * 0.005)
                        )
                        .frame(width: radius * 2, height: radius * 2)
                }

                ForEach(Array(orbitingProviders.enumerated()), id: \.offset) { index, provider in
                    let orbitIndex = activeOrbitIndices[index]
                    let radius = canonicalOrbitRadii[orbitIndex]
                    let targetOffset = circularOrbitOffset(
                        angleDegrees: (time * orbitSpeeds[orbitIndex]) + phaseOffsets[orbitIndex],
                        radius: radius
                    )
                    let entryOffset = CGSize(
                        width: targetOffset.width * 1.8 + size * 0.22,
                        height: targetOffset.height * 1.8 - size * 0.24
                    )
                    let planetOffset = CGSize(
                        width: entryOffset.width + (targetOffset.width - entryOffset.width) * introProgress,
                        height: entryOffset.height + (targetOffset.height - entryOffset.height) * introProgress
                    )

                    Circle()
                        .fill(planetColor(for: provider))
                        .frame(width: planetSizes[index], height: planetSizes[index])
                        .overlay {
                            Circle()
                                .fill(Color.white.opacity(0.52))
                                .frame(width: planetSizes[index] * 0.28, height: planetSizes[index] * 0.28)
                                .offset(x: -planetSizes[index] * 0.16, y: -planetSizes[index] * 0.16)
                        }
                        .shadow(color: planetColor(for: provider).opacity(0.45), radius: size * 0.1)
                        .offset(x: planetOffset.width, y: planetOffset.height)
                        .opacity(introOpacity)
                        .scaleEffect(0.78 + (0.22 * introProgress))
                }
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            sunCore,
                            sunEdge,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: sunSize, height: sunSize)
                .overlay {
                    Circle()
                        .stroke(sunEdge.opacity(0.22), lineWidth: max(0.5, size * 0.025))
                }
                .scaleEffect(pulseScale)
                .shadow(color: sunEdge.opacity(0.4), radius: size * 0.12)
        }
    }

    private var providerSignature: String {
        planetProviders.map(\.rawValue).joined(separator: "|")
    }

    private func orbitIntroProgress(at time: TimeInterval) -> CGFloat {
        guard animateOrbit else { return 1 }

        let elapsed = max(0, time - orbitEntryStart.timeIntervalSinceReferenceDate)
        let raw = min(elapsed / 0.72, 1)
        let t = raw - 1
        return CGFloat(1 + (t * t * ((1.35 + 1) * t + 1.35)))
    }

    private func distributedOrbitIndices(activeCount: Int, totalSlots: Int) -> [Int] {
        guard activeCount > 0, totalSlots > 0 else { return [] }
        if activeCount >= totalSlots {
            return Array(0..<totalSlots)
        }
        if activeCount == 1 {
            return [totalSlots / 2]
        }

        var indices: [Int] = []
        let step = Double(totalSlots - 1) / Double(activeCount - 1)

        for i in 0..<activeCount {
            let candidate = Int(round(Double(i) * step))
            if !indices.contains(candidate) {
                indices.append(candidate)
            }
        }

        if indices.count < activeCount {
            for candidate in 0..<totalSlots where !indices.contains(candidate) {
                indices.append(candidate)
                if indices.count == activeCount {
                    break
                }
            }
        }

        return indices.sorted()
    }

    private func scaledOrbitRadii(
        distancesAU: [CGFloat],
        minRadius: CGFloat,
        maxRadius: CGFloat
    ) -> [CGFloat] {
        guard let minDistance = distancesAU.min(),
              let maxDistance = distancesAU.max(),
              minDistance > 0,
              maxDistance > minDistance else {
            return distancesAU
        }

        let minLog = log(minDistance)
        let maxLog = log(maxDistance)
        let span = maxLog - minLog
        let evenDenominator = CGFloat(max(distancesAU.count - 1, 1))
        let blendFactor: CGFloat = 0.4

        return distancesAU.enumerated().map { index, distance in
            let normalized = (log(distance) - minLog) / span
            let evenNormalized = CGFloat(index) / evenDenominator
            let blended = (normalized * (1 - blendFactor)) + (evenNormalized * blendFactor)
            return minRadius + (maxRadius - minRadius) * blended
        }
    }

    private func circularOrbitOffset(
        angleDegrees: Double,
        radius: CGFloat
    ) -> CGSize {
        let theta = CGFloat(angleDegrees * .pi / 180)
        return CGSize(
            width: cos(theta) * radius,
            height: sin(theta) * radius
        )
    }

    private func planetColor(for provider: SessionProviderKind) -> Color {
        switch provider {
        case .codex:
            return Color(red: 0.69, green: 0.95, blue: 0.28)
        case .claude:
            return Color(red: 0.95, green: 0.49, blue: 0.24)
        case .gemini:
            return Color(red: 0.42, green: 0.57, blue: 1.0)
        }
    }
}

struct CodexGlyphIcon: View {
    let size: CGFloat
    var animateGlow: Bool = false

    @State private var glowPulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 0.97, blue: 0.86).opacity(0.24),
                            Color(red: 0.74, green: 0.86, blue: 0.16).opacity(0.05),
                            .clear,
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.82
                    )
                )
                .scaleEffect(animateGlow && glowPulse ? 1.08 : 0.94)

            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: size * 0.52, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.99, blue: 0.92),
                            Color(red: 0.86, green: 0.95, blue: 0.34),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(red: 0.85, green: 0.95, blue: 0.24).opacity(0.42), radius: 6, y: 1)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.9), value: glowPulse)
        .onAppear {
            guard animateGlow else { return }
            glowPulse = true
        }
        .onChange(of: animateGlow) { _, newValue in
            glowPulse = newValue
        }
    }
}

// Pixel art permission indicator icon
struct PermissionIndicatorIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 14, color: Color = Color(red: 0.11, green: 0.12, blue: 0.13)) {
        self.size = size
        self.color = color
    }

    // Visible pixel positions from the SVG (at 30x30 scale)
    private let pixels: [(CGFloat, CGFloat)] = [
        (7, 7), (7, 11),           // Left column
        (11, 3),                    // Top left
        (15, 3), (15, 19), (15, 27), // Center column
        (19, 3), (19, 15),          // Right of center
        (23, 7), (23, 11)           // Right column
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let pixelSize: CGFloat = 4 * scale

            for (x, y) in pixels {
                let rect = CGRect(
                    x: x * scale - pixelSize / 2,
                    y: y * scale - pixelSize / 2,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// Pixel art "ready for input" indicator icon (checkmark/done shape)
struct ReadyForInputIndicatorIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 14, color: Color = TerminalColors.green) {
        self.size = size
        self.color = color
    }

    // Checkmark shape pixel positions (at 30x30 scale)
    private let pixels: [(CGFloat, CGFloat)] = [
        (5, 15),                    // Start of checkmark
        (9, 19),                    // Down stroke
        (13, 23),                   // Bottom of checkmark
        (17, 19),                   // Up stroke begins
        (21, 15),                   // Up stroke
        (25, 11),                   // Up stroke
        (29, 7)                     // End of checkmark
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let pixelSize: CGFloat = 4 * scale

            for (x, y) in pixels {
                let rect = CGRect(
                    x: x * scale - pixelSize / 2,
                    y: y * scale - pixelSize / 2,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}
