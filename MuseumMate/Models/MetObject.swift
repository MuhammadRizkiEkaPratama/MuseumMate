//
//  MetObject.swift
//  MuseumMate
//
//  A single object from the Metropolitan Museum of Art Collection API.
//  Decoding is tolerant — the API returns many fields and some may be
//  empty; we only keep what the Dashboard needs.
//

import Foundation

struct MetObject: Codable, Identifiable, Equatable {
    let objectID: Int
    let title: String
    let artistDisplayName: String
    let objectDate: String
    let medium: String
    let department: String
    let primaryImage: String
    let primaryImageSmall: String
    let objectURL: String
    let isHighlight: Bool
    let culture: String
    let period: String
    let creditLine: String

    var id: Int { objectID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        objectID = (try? c.decode(Int.self, forKey: .objectID)) ?? 0
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        artistDisplayName = (try? c.decode(String.self, forKey: .artistDisplayName)) ?? ""
        objectDate = (try? c.decode(String.self, forKey: .objectDate)) ?? ""
        medium = (try? c.decode(String.self, forKey: .medium)) ?? ""
        department = (try? c.decode(String.self, forKey: .department)) ?? ""
        primaryImage = (try? c.decode(String.self, forKey: .primaryImage)) ?? ""
        primaryImageSmall = (try? c.decode(String.self, forKey: .primaryImageSmall)) ?? ""
        objectURL = (try? c.decode(String.self, forKey: .objectURL)) ?? ""
        isHighlight = (try? c.decode(Bool.self, forKey: .isHighlight)) ?? false
        culture = (try? c.decode(String.self, forKey: .culture)) ?? ""
        period = (try? c.decode(String.self, forKey: .period)) ?? ""
        creditLine = (try? c.decode(String.self, forKey: .creditLine)) ?? ""
    }

    // Memberwise init for caching / previews.
    init(objectID: Int, title: String, artistDisplayName: String, objectDate: String,
         medium: String, department: String, primaryImage: String, primaryImageSmall: String,
         objectURL: String, isHighlight: Bool, culture: String, period: String, creditLine: String) {
        self.objectID = objectID
        self.title = title
        self.artistDisplayName = artistDisplayName
        self.objectDate = objectDate
        self.medium = medium
        self.department = department
        self.primaryImage = primaryImage
        self.primaryImageSmall = primaryImageSmall
        self.objectURL = objectURL
        self.isHighlight = isHighlight
        self.culture = culture
        self.period = period
        self.creditLine = creditLine
    }

    var hasValidImage: Bool { !primaryImage.isEmpty }
    var artistOrUnknown: String { artistDisplayName.isEmpty ? "Unknown artist" : artistDisplayName }

    static let preview = MetObject(
        objectID: 436535,
        title: "Wheat Field with Cypresses",
        artistDisplayName: "Vincent van Gogh",
        objectDate: "1889",
        medium: "Oil on canvas",
        department: "European Paintings",
        primaryImage: "",
        primaryImageSmall: "",
        objectURL: "https://www.metmuseum.org/art/collection/search/436535",
        isHighlight: true,
        culture: "",
        period: "",
        creditLine: "Purchase, The Annenberg Foundation Gift, 1993"
    )

    /// Hardcoded fallback shown when the Met API is unavailable.
    static let fallback = MetObject(
        objectID: 436535,
        title: "Wheat Field with Cypresses",
        artistDisplayName: "Vincent van Gogh",
        objectDate: "1889",
        medium: "Oil on canvas",
        department: "European Paintings",
        primaryImage: "https://images.metmuseum.org/CRDImages/ep/original/DT1567.jpg",
        primaryImageSmall: "https://images.metmuseum.org/CRDImages/ep/web-large/DT1567.jpg",
        objectURL: "https://www.metmuseum.org/art/collection/search/436535",
        isHighlight: true,
        culture: "",
        period: "",
        creditLine: "Purchase, The Annenberg Foundation Gift, 1993"
    )
}

/// Response shape for /objects?isHighlight=true&hasImages=true
struct MetObjectIDs: Codable {
    let total: Int
    let objectIDs: [Int]?
}
