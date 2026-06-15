//
//  ArtStyle.swift
//  MuseumMate
//
//  Art-style metadata. The eight names MUST match the Create ML dataset
//  folder labels exactly (underscores are normalized to spaces at runtime).
//

import SwiftUI

struct ArtStyle: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let period: String
    let shortDescription: String
    let accentColorHex: String
    var accentColor: Color { Color(hex: accentColorHex) }

    static func == (lhs: ArtStyle, rhs: ArtStyle) -> Bool { lhs.name == rhs.name }
}

extension ArtStyle {
    /// Broad historical grouping, used to organize styles in the UI.
    var era: String {
        switch name {
        case "Renaissance", "Baroque":
            return "Classical Era"
        case "Romanticism", "Realism", "Impressionism":
            return "19th Century"
        case "Cubism", "Surrealism", "Pop Art":
            return "Modern & Contemporary"
        default:
            return "Other Movements"
        }
    }
}

struct ArtStyleLibrary {
    // 8 styles — MUST match the Create ML dataset folder labels exactly.
    static let all: [ArtStyle] = [
        ArtStyle(name: "Impressionism", period: "1860s–1880s",
                 shortDescription: "Quick brushwork, focus on light and momentary impressions.",
                 accentColorHex: "#5B8DEF"),
        ArtStyle(name: "Baroque", period: "1600s–1750s",
                 shortDescription: "Dramatic, strong light-dark contrast, grandeur.",
                 accentColorHex: "#C9A227"),
        ArtStyle(name: "Renaissance", period: "1400s–1600s",
                 shortDescription: "Proportion, perspective, classical realism.",
                 accentColorHex: "#A0522D"),
        ArtStyle(name: "Cubism", period: "1907–1920s",
                 shortDescription: "Geometric forms, multiple viewpoints at once.",
                 accentColorHex: "#E07A5F"),
        ArtStyle(name: "Surrealism", period: "1920s–1950s",
                 shortDescription: "Dreams, the subconscious, illusion.",
                 accentColorHex: "#8E7CC3"),
        ArtStyle(name: "Pop Art", period: "1950s–1970s",
                 shortDescription: "Popular culture, bold colors, iconic imagery.",
                 accentColorHex: "#EF476F"),
        ArtStyle(name: "Romanticism", period: "1800s–1850s",
                 shortDescription: "Emotion, wild nature, the sublime.",
                 accentColorHex: "#06A77D"),
        ArtStyle(name: "Realism", period: "1840s–1880s",
                 shortDescription: "Everyday life depicted as it is.",
                 accentColorHex: "#6C757D"),
    ]

    /// Eras in display order, for grouped UI.
    static let eras: [String] = ["Classical Era", "19th Century", "Modern & Contemporary"]

    static func styles(in era: String) -> [ArtStyle] {
        all.filter { $0.era == era }
    }

    /// Tolerant lookup — matches even when the cloud returns a richer label
    /// like "Post-Impressionism" or an underscored Core ML identifier.
    static func style(named name: String) -> ArtStyle? {
        let needle = name
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !needle.isEmpty else { return nil }
        if let exact = all.first(where: { $0.name.lowercased() == needle }) {
            return exact
        }
        // Partial match: "post-impressionism" → Impressionism, etc.
        return all.first { needle.contains($0.name.lowercased()) || $0.name.lowercased().contains(needle) }
    }

    /// Accent color for any style label, falling back to museum gold.
    static func accentColor(for name: String) -> Color {
        style(named: name)?.accentColor ?? .appAccent
    }
}
