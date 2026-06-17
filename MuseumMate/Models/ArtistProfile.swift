//
//  ArtistProfile.swift
//  MuseumMate
//
//  A rich artist biography produced by ArtistInfoService (DeepSeek V4 Pro).
//

import SwiftUI

struct ArtistProfile: Identifiable, Codable {
    var id = UUID()
    var name: String
    var nationality: String
    var born: String
    var died: String
    var movement: String
    var bio: String
    var famousWorks: [String]
    var portraitURL: String
    var accentColorHex: String

    enum CodingKeys: String, CodingKey {
        case name, nationality, born, died, movement, bio
        case famousWorks = "famous_works"
        case portraitURL = "portrait_url"
        case accentColorHex = "accent_color_hex"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name          = (try? c.decode(String.self,   forKey: .name))          ?? ""
        nationality   = (try? c.decode(String.self,   forKey: .nationality))   ?? ""
        born          = (try? c.decode(String.self,   forKey: .born))          ?? ""
        died          = (try? c.decode(String.self,   forKey: .died))          ?? ""
        movement      = (try? c.decode(String.self,   forKey: .movement))      ?? ""
        bio           = (try? c.decode(String.self,   forKey: .bio))           ?? ""
        famousWorks   = (try? c.decode([String].self, forKey: .famousWorks))   ?? []
        portraitURL   = (try? c.decode(String.self,   forKey: .portraitURL))   ?? ""
        accentColorHex = (try? c.decode(String.self,  forKey: .accentColorHex)) ?? "#C9A227"
    }

    init(name: String, nationality: String, born: String, died: String,
         movement: String, bio: String, famousWorks: [String],
         portraitURL: String = "", accentColorHex: String = "#C9A227") {
        self.name           = name
        self.nationality    = nationality
        self.born           = born
        self.died           = died
        self.movement       = movement
        self.bio            = bio
        self.famousWorks    = famousWorks
        self.portraitURL    = portraitURL
        self.accentColorHex = accentColorHex
    }

    var accentColor: Color { Color(hex: accentColorHex) }
    var lifespan: String { "\(born) – \(died)" }
}
