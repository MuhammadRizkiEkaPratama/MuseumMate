//
//  StyleOverlayView.swift
//  MuseumMate
//
//  The live artist badge: a floating blurred pill with an accent stripe.
//  Shows artist last name + movement; cross-fades when the detection changes.
//

import SwiftUI

struct StyleOverlayView: View {
    let style: String       // the detectedArtist value
    let confidence: Double

    private var artist: Artist? { ArtistLibrary.artist(fromLabel: style) }
    private var accent: Color { artist?.accentColor ?? ArtistLibrary.accentColor(for: style) }
    private var hasResult: Bool { style != "—" && !style.isEmpty && style != "unknown" }

    /// Last name only when the full name is long (e.g. "Van Gogh" not "Vincent van Gogh").
    private var displayName: String {
        guard let artist else { return style }
        let parts = artist.name.components(separatedBy: " ")
        return parts.count > 2 ? (parts.last ?? artist.name) : artist.name
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(hasResult ? displayName : "Searching…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                if hasResult {
                    Text(artist?.movement ?? "\(Int(confidence * 100))% match")
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
        .id(style)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: style)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasResult
            ? "Detected artist \(displayName), \(artist?.movement ?? "")"
            : "Searching for artist")
    }
}

struct StyleOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            StyleOverlayView(style: "Vincent van Gogh", confidence: 0.85)
        }
        .preferredColorScheme(.dark)
    }
}
