//
//  Artwork.swift
//  MuseumMate
//
//  The DeepSeek identification result. Field names and CodingKeys are a
//  binding contract with VisionService — do not rename them.
//

import Foundation

struct Artwork: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var artist: String
    var year: String          // String — may be "c. 1500"
    var medium: String
    var style: String
    var location: String      // museum/gallery holding the original
    var description: String
    var funFacts: [String]
    var confidence: Double

    enum CodingKeys: String, CodingKey {
        case title, artist, year, medium, style
        case location, description, funFacts = "fun_facts", confidence
    }
}

extension Artwork {
    var isUnknown: Bool {
        title.trimmingCharacters(in: .whitespaces).lowercased() == "unknown"
            || title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// "Year • Medium" metadata line, skipping empty parts.
    var metadataLine: String {
        [year, medium]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "  •  ")
    }

    static let preview = Artwork(
        title: "The Starry Night",
        artist: "Vincent van Gogh",
        year: "1889",
        medium: "Oil on canvas",
        style: "Post-Impressionism",
        location: "Museum of Modern Art, New York",
        description: "Painted in June 1889, The Starry Night depicts the view from the east-facing window of van Gogh's asylum room at Saint-Rémy-de-Provence, just before sunrise, with the addition of an idealized village.\n\nThe swirling sky, luminous crescent moon, and exaggerated stars convey an emotional intensity that would become a hallmark of Expressionism decades later.",
        funFacts: [
            "Van Gogh painted it from memory during the day, not at night.",
            "It is one of the most recognized paintings in Western art.",
            "The cypress tree in the foreground traditionally symbolizes death and eternity."
        ],
        confidence: 0.97
    )
}
