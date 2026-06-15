//
//  LoadingView.swift
//  MuseumMate
//
//  Loading states for the whole app. Museum galleries don't spin —
//  so we pulse gold instead of using ProgressView spinners.
//  All animations honor Reduce Motion.
//

import SwiftUI

// MARK: - Pulsing gold ring

/// A breathing gold ring used while a scan or network call is in flight.
struct PulsingRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 48
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(Color.appAccent, lineWidth: 3)
            .frame(width: size, height: size)
            .opacity(animate ? 1.0 : 0.3)
            .scaleEffect(animate ? 1.0 : 0.85)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
            .accessibilityLabel("Loading")
    }
}

// MARK: - Pulsing dots (inline, e.g. inside buttons)

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

// MARK: - Full loading view with phase label

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            PulsingRing()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .transition(.opacity)
                .id(message)   // cross-fade when the message changes
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: message)
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView(message: "Identifying artwork…")
            .frame(maxHeight: .infinity)
            .background(Color.appBackground)
            .preferredColorScheme(.dark)
    }
}
