//
//  ScanResult.swift
//  MuseumMate
//
//  One full scan session: the saved image, the offline style guess,
//  and the optional cloud identification.
//

import Foundation

struct ScanResult: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var imageFileName: String
    var thumbnailFileName: String?   // 300×300 JPEG for list/grid views
    var localArtist: String          // Core ML result
    var localConfidence: Double
    var artwork: Artwork?            // DeepSeek result (nil when offline)
    var isFavorite: Bool = false
}

extension ScanResult {
    var hasCloudData: Bool { artwork != nil }

    var displayTitle: String {
        if let title = artwork?.title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            return title
        }
        let style = localArtist == "unknown" ? "Artwork" : localArtist
        return "Untitled \(style)"
    }

    var displayStyle: String {
        if let style = artwork?.style, !style.trimmingCharacters(in: .whitespaces).isEmpty {
            return style
        }
        return localArtist
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static let preview = ScanResult(
        date: Date(),
        imageFileName: "preview.jpg",
        thumbnailFileName: nil,
        localArtist: "Vincent van Gogh",
        localConfidence: 0.82,
        artwork: .preview,
        isFavorite: true
    )
}
