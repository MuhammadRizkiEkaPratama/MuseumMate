//
//  Artwork.swift
//  MuseumMate
//
//  The catalog entry produced by the DeepSeek detail stage. Field names and
//  CodingKeys are a binding contract with ArtworkDetailService — do not rename.
//

import Foundation

struct Artwork: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var artist: String
    var year: String
    var medium: String
    var style: String
    var location: String
    var description: String
    var funFacts: [String]
    var confidence: Double
    var quote: String
    var creationStory: String
    var romanticLine: String
    // Extended catalog fields (Part 2C)
    var artistNationality: String
    var exhibitionLocation: String
    var exhibitionSince: String
    var category: String
    var artStyle: String
    var creationTime: String
    var material: String
    var theme: String
    var genre: String
    var shortHistory: String
    var lovePoems: [String]
    var artistStory: String

    enum CodingKeys: String, CodingKey {
        case title, artist, year, medium, style
        case location, description
        case funFacts = "fun_facts"
        case confidence
        case quote
        case creationStory     = "creation_story"
        case romanticLine      = "romantic_line"
        case artistNationality = "artist_nationality"
        case exhibitionLocation = "exhibition_location"
        case exhibitionSince   = "exhibition_since"
        case category
        case artStyle          = "art_style"
        case creationTime      = "creation_time"
        case material, theme, genre
        case shortHistory      = "short_history"
        case lovePoems         = "love_poems"
        case artistStory       = "artist_story"
    }

    // Custom decoder: missing keys fall back to empty so old persisted data still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title              = (try? c.decode(String.self,   forKey: .title))              ?? ""
        artist             = (try? c.decode(String.self,   forKey: .artist))             ?? ""
        year               = (try? c.decode(String.self,   forKey: .year))               ?? ""
        medium             = (try? c.decode(String.self,   forKey: .medium))             ?? ""
        style              = (try? c.decode(String.self,   forKey: .style))              ?? ""
        location           = (try? c.decode(String.self,   forKey: .location))           ?? ""
        description        = (try? c.decode(String.self,   forKey: .description))        ?? ""
        funFacts           = (try? c.decode([String].self, forKey: .funFacts))           ?? []
        confidence         = (try? c.decode(Double.self,   forKey: .confidence))         ?? 0
        quote              = (try? c.decode(String.self,   forKey: .quote))              ?? ""
        creationStory      = (try? c.decode(String.self,   forKey: .creationStory))      ?? ""
        romanticLine       = (try? c.decode(String.self,   forKey: .romanticLine))       ?? ""
        artistNationality  = (try? c.decode(String.self,   forKey: .artistNationality))  ?? ""
        exhibitionLocation = (try? c.decode(String.self,   forKey: .exhibitionLocation)) ?? ""
        exhibitionSince    = (try? c.decode(String.self,   forKey: .exhibitionSince))    ?? ""
        category           = (try? c.decode(String.self,   forKey: .category))           ?? ""
        artStyle           = (try? c.decode(String.self,   forKey: .artStyle))           ?? ""
        creationTime       = (try? c.decode(String.self,   forKey: .creationTime))       ?? ""
        material           = (try? c.decode(String.self,   forKey: .material))           ?? ""
        theme              = (try? c.decode(String.self,   forKey: .theme))              ?? ""
        genre              = (try? c.decode(String.self,   forKey: .genre))              ?? ""
        shortHistory       = (try? c.decode(String.self,   forKey: .shortHistory))       ?? ""
        lovePoems          = (try? c.decode([String].self, forKey: .lovePoems))          ?? []
        artistStory        = (try? c.decode(String.self,   forKey: .artistStory))        ?? ""
    }

    // Memberwise init for previews and manual construction.
    init(
        title: String, artist: String, year: String, medium: String, style: String,
        location: String, description: String, funFacts: [String], confidence: Double,
        quote: String = "", creationStory: String = "", romanticLine: String = "",
        artistNationality: String = "", exhibitionLocation: String = "",
        exhibitionSince: String = "", category: String = "", artStyle: String = "",
        creationTime: String = "", material: String = "", theme: String = "",
        genre: String = "", shortHistory: String = "", lovePoems: [String] = [],
        artistStory: String = ""
    ) {
        self.title              = title
        self.artist             = artist
        self.year               = year
        self.medium             = medium
        self.style              = style
        self.location           = location
        self.description        = description
        self.funFacts           = funFacts
        self.confidence         = confidence
        self.quote              = quote
        self.creationStory      = creationStory
        self.romanticLine       = romanticLine
        self.artistNationality  = artistNationality
        self.exhibitionLocation = exhibitionLocation
        self.exhibitionSince    = exhibitionSince
        self.category           = category
        self.artStyle           = artStyle
        self.creationTime       = creationTime
        self.material           = material
        self.theme              = theme
        self.genre              = genre
        self.shortHistory       = shortHistory
        self.lovePoems          = lovePoems
        self.artistStory        = artistStory
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
        romanticLine: "Like van Gogh's stars, every time I look at you, the whole sky seems to swirl just for us.",
        artistNationality: "Dutch",
        exhibitionLocation: "Museum of Modern Art, New York",
        exhibitionSince: "1941",
        category: "Painting",
        artStyle: "Post-Impressionism",
        creationTime: "June 1889",
        material: "Oil on canvas, 73.7 × 92.1 cm",
        theme: "Night sky, spirituality, nature",
        genre: "Landscape",
        shortHistory: "Painted during van Gogh's stay at an asylum in Saint-Rémy-de-Provence, The Starry Night became one of the most iconic works in Western art. It entered MoMA's permanent collection in 1941.",
        lovePoems: [
            "Like van Gogh's stars, every time I look at you, the whole sky seems to swirl just for us.",
            "In the swirl of your eyes I find the same infinite wonder as in this painted night.",
            "Let us be like the village beneath the stars — small, warm, and certain of each other."
        ],
        artistStory: "Vincent van Gogh sold only one painting in his lifetime, yet produced over 2,100 works. Tormented by mental illness and fueled by an almost supernatural passion, he created his greatest masterpieces in the final two years of his life."
    )
}
