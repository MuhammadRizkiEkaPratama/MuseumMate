//
//  LoadingView.swift
//  MuseumMate
//
//  Cinematic museum-grade loading states.
//  An animated gold frame draws itself, then the "M" lettermark fades in.
//  Phase labels cross-fade as scanning progresses.
//

import SwiftUI

// MARK: - Full scanning overlay (replaces the old LoadingView)

struct LoadingView: View {
    let message: String

    @State private var frameTrim: CGFloat = 0
    @State private var logoOpacity: Double = 0
    @State private var pulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 28) {
            museumFrame
            phaseLabel
        }
        .frame(maxWidth: .infinity)
        .onAppear { animate() }
        .animation(.easeInOut(duration: 0.25), value: message)
    }

    // MARK: - Animated golden frame with M lettermark

    private var museumFrame: some View {
        ZStack {
            // Outer glow ring (always visible, subtle)
            Circle()
                .stroke(Color.appAccent.opacity(0.12), lineWidth: 20)
                .frame(width: 96, height: 96)

            // Drawing gold frame
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .trim(from: 0, to: frameTrim)
                .stroke(
                    Color.appAccent,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 86, height: 86)
                .rotationEffect(.degrees(-90))

            // Corner accents (static, drawn after frame)
            cornerAccents
                .opacity(frameTrim >= 1 ? 1 : 0)
                .animation(.easeIn(duration: 0.2).delay(0.5), value: frameTrim)

            // M lettermark
            Text("M")
                .font(.system(size: 38, design: .serif).weight(.light))
                .foregroundStyle(Color.appAccent)
                .opacity(logoOpacity)
                .scaleEffect(pulse ? 1.06 : 0.98)
                .animation(
                    reduceMotion ? nil :
                    .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                    value: pulse
                )
        }
        .frame(width: 96, height: 96)
    }

    // Four corner tick marks (museum frame corners)
    private var cornerAccents: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let angle = Double(i) * 90.0
                cornerTick
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: 96, height: 96)
    }

    private var cornerTick: some View {
        Path { p in
            p.move(to: CGPoint(x: 48 - 44, y: 48 - 44 + 10))
            p.addLine(to: CGPoint(x: 48 - 44, y: 48 - 44))
            p.addLine(to: CGPoint(x: 48 - 44 + 10, y: 48 - 44))
        }
        .stroke(Color.appAccent.opacity(0.5), lineWidth: 1.5)
    }

    // MARK: - Phase label with pulsing dots

    private var phaseLabel: some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .transition(.opacity)
                .id(message)

            // Pulsing gold dots
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 5, height: 5)
                        .opacity(pulse ? 1.0 : 0.15)
                        .animation(
                            reduceMotion ? nil :
                            .easeInOut(duration: 0.55)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.18),
                            value: pulse
                        )
                }
            }
        }
    }

    // MARK: - Animation sequence

    private func animate() {
        if reduceMotion {
            frameTrim = 1
            logoOpacity = 1
            pulse = true
            return
        }
        withAnimation(.easeOut(duration: 0.75)) {
            frameTrim = 1
        }
        withAnimation(.easeIn(duration: 0.35).delay(0.65)) {
            logoOpacity = 1
        }
        // Pulse starts after frame and logo are shown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            pulse = true
        }
    }
}

// MARK: - Inline pulsing ring (used for skeleton / small indicators)

struct PulsingRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 48
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(Color.appAccent, lineWidth: 2.5)
            .frame(width: size, height: size)
            .opacity(animate ? 1.0 : 0.25)
            .scaleEffect(animate ? 1.0 : 0.82)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
            .accessibilityLabel("Loading")
    }
}

// MARK: - Inline pulsing dots (inside buttons, cards)

struct PulsingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var color: Color = .appBackground
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .opacity(animate ? 1.0 : 0.3)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.18),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .accessibilityLabel("Loading")
    }
}

// MARK: - Preview

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView(message: "Identifying artwork…")
            .frame(maxHeight: .infinity)
            .background(Color.appBackground)
            .preferredColorScheme(.dark)
    }
}
