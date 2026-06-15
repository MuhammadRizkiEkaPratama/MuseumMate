//
//  StyleOverlayView.swift
//  MuseumMate
//
//  The live style badge: a floating blurred pill with an accent stripe.
//  Cross-fades gently when the detected style changes.
//

import SwiftUI

struct StyleOverlayView: View {
    let style: String
    let confidence: Double

    private var accent: Color { ArtStyleLibrary.accentColor(for: style) }
    private var hasStyle: Bool { style != "—" && !style.isEmpty }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(hasStyle ? style : "Searching…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                if hasStyle {
                    Text("\(Int(confidence * 100))% match")
                        .font(.caption2)
                        .foregroundStyle(Color.appTextMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 48)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .id(style)   // drives the cross-fade on change
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: style)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasStyle ? "Detected style \(style), \(Int(confidence * 100)) percent" : "Searching for a style")
    }
}

struct StyleOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            StyleOverlayView(style: "Impressionism", confidence: 0.78)
        }
        .preferredColorScheme(.dark)
    }
}
