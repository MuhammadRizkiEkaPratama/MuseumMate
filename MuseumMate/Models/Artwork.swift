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
    var quote: String          // poetic quote this artwork evokes
    var creationStory: String  // backstory of how/why this was painted
    var romanticLine: String   // sweet line to share with someone special

    enum CodingKeys: String, CodingKey {
        case title, artist, year, medium, style
        case location, description, funFacts = "fun_facts", confidence
        case quote
        case creationStory = "creation_story"
        case romanticLine = "romantic_line"
    }

    // Custom decoder so old persisted Artwork objects (without the new fields)
    // still decode successfully — missing keys fall back to empty strings.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title         = (try? c.decode(String.self,   forKey: .title))         ?? ""
        artist        = (try? c.decode(String.self,   forKey: .artist))        ?? ""
        year          = (try? c.decode(String.self,   forKey: .year))          ?? ""
        medium        = (try? c.decode(String.self,   forKey: .medium))        ?? ""
        style         = (try? c.decode(String.self,   forKey: .style))         ?? ""
        location      = (try? c.decode(String.self,   forKey: .location))      ?? ""
        description   = (try? c.decode(String.self,   forKey: .description))   ?? ""
        funFacts      = (try? c.decode([String].self, forKey: .funFacts))      ?? []
        confidence    = (try? c.decode(Double.self,   forKey: .confidence))    ?? 0
        quote         = (try? c.decode(String.self,   forKey: .quote))         ?? ""
        creationStory = (try? c.decode(String.self,   forKey: .creationStory)) ?? ""
        romanticLine  = (try? c.decode(String.self,   forKey: .romanticLine))  ?? ""
    }

    // Memberwise init for previews and manual construction.
    init(title: String, artist: String, year: String, medium: String, style: String,
         location: String, description: String, funFacts: [String], confidence: Double,
         quote: String = "", creationStory: String = "", romanticLine: String = "") {
        self.title         = title
        self.artist        = artist
        self.year          = year
        self.medium        = medium
        self.style         = style
        self.location      = location
        self.description   = description
        self.funFacts      = funFacts
        self.confidence    = confidence
        self.quote         = quote
        self.creationStory = creationStory
        self.romanticLine  = romanticLine
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
        confidence: 0.97,
        quote: "I dream of painting and then I paint my dream.",
        creationStory: "Van Gogh painted The Starry Night while voluntarily residing at the Saint-Paul-de-Mausole asylum following his breakdown in Arles. He requested to paint in his room and the surrounding wheat fields, producing over 150 works during his year there. The swirling night sky was born from a desperate longing for the world beyond his barred window.",
        romanticLine: "Like van Gogh's stars, every time I look at you, the whole sky seems to swirl just for us."
    )
}
