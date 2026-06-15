//
//  View+Extensions.swift
//  MuseumMate
//
//  Design-system helpers: one card style, one button style,
//  one animation vocabulary — consistency over novelty.
//

import SwiftUI
import UIKit

// MARK: - Animation vocabulary

extension Animation {
    /// The single spring used for all movement in the app.
    static let museumSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
}

// MARK: - Button style

/// Gently scales the label down while pressed — the app-wide button feel.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.museumSpring, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Entrance animation

/// Fade + slide entrance. Stagger list items by passing an index-based delay.
/// Honors Reduce Motion by fading in place without movement.
struct FadeSlideIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delay: Double
    @State private var isShown = false

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown || reduceMotion ? 0 : 14)
            .onAppear {
                let animation: Animation = reduceMotion
                    ? .easeIn(duration: 0.25)
                    : .museumSpring
                withAnimation(animation.delay(delay)) {
                    isShown = true
                }
            }
    }
}

// MARK: - Haptics

/// Light haptic feedback for key actions (scan, favorite, capture).
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - View helpers

extension View {
    /// Layered museum card: surface fill, hairline border, continuous corners.
    func card(padding: CGFloat = 16, cornerRadius: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    /// Uppercased, letter-spaced caption above sections — museum-label style.
    func sectionLabel() -> some View {
        self
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .kerning(1.4)
            .foregroundStyle(Color.appTextMuted)
    }

    /// Fade + slide entrance; pass a per-item delay to stagger lists.
    func fadeSlideIn(delay: Double = 0) -> some View {
        modifier(FadeSlideIn(delay: delay))
    }

    /// Conditionally applies a transform to the view.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
