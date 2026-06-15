//
//  MemoryPhoto.swift
//  MuseumMate
//
//  A photo captured during a museum visit, optionally linked to a scan.
//

import Foundation

struct MemoryPhoto: Identifiable, Codable, Equatable {
    var id = UUID()
    var imageFileName: String
    var caption: String = ""
    var dateTaken: Date
    var linkedScanResultID: UUID?
    var linkedScanTitle: String?

    var isLinked: Bool { linkedScanResultID != nil }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateTaken)
    }
}
