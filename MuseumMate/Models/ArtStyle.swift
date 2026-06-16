//
//  ArtStyle.swift
//  MuseumMate
//
//  Artist metadata matching the 12 classes in ArtistClassifier.mlmodel.
//  Labels normalize underscores and hyphens to spaces for matching.
//

import SwiftUI

struct Artist: Identifiable {
    let id = UUID()
    let name: String           // display name
    let datasetLabel: String   // exact folder name used in training
    let nationality: String
    let movement: String
    let born: String
    let died: String
    let accentColorHex: String
    var accentColor: Color { Color(hex: accentColorHex) }
}

struct ArtistLibrary {
    // 12 artists — labels MUST match the Create ML dataset folder names exactly.
    static let all: [Artist] = [
        Artist(name: "Vincent van Gogh", datasetLabel: "Vincent van Gogh",
               nationality: "Dutch", movement: "Post-Impressionism",
               born: "1853", died: "1890", accentColorHex: "#E8B84B"),
        Artist(name: "Edgar Degas", datasetLabel: "Edgar Degas",
               nationality: "French", movement: "Impressionism",
               born: "1834", died: "1917", accentColorHex: "#7B9EA6"),
        Artist(name: "Pablo Picasso", datasetLabel: "Pablo Picasso",
               nationality: "Spanish", movement: "Cubism",
               born: "1881", died: "1973", accentColorHex: "#C17B5C"),
        Artist(name: "Pierre-Auguste Renoir", datasetLabel: "Pierre-Auguste Renoir",
               nationality: "French", movement: "Impressionism",
               born: "1841", died: "1919", accentColorHex: "#A8C5A0"),
        Artist(name: "Paul Gauguin", datasetLabel: "Paul Gauguin",
               nationality: "French", movement: "Post-Impressionism",
               born: "1848", died: "1903", accentColorHex: "#D4956A"),
        Artist(name: "Francisco Goya", datasetLabel: "Francisco Goya",
               nationality: "Spanish", movement: "Romanticism",
               born: "1746", died: "1828", accentColorHex: "#8B7355"),
        Artist(name: "Rembrandt", datasetLabel: "Rembrandt",
               nationality: "Dutch", movement: "Baroque",
               born: "1606", died: "1669", accentColorHex: "#C9A227"),
        Artist(name: "Titian", datasetLabel: "Titian",
               nationality: "Italian", movement: "Renaissance",
               born: "1488", died: "1576", accentColorHex: "#9B6B8A"),
        Artist(name: "Sandro Botticelli", datasetLabel: "Sandro Botticelli",
               nationality: "Italian", movement: "Renaissance",
               born: "1445", died: "1510", accentColorHex: "#6B8FA8"),
        Artist(name: "Leonardo da Vinci", datasetLabel: "Leonardo da Vinci",
               nationality: "Italian", movement: "Renaissance",
               born: "1452", died: "1519", accentColorHex: "#8B9B6B"),
        Artist(name: "Salvador Dali", datasetLabel: "Salvador Dali",
               nationality: "Spanish", movement: "Surrealism",
               born: "1904", died: "1989", accentColorHex: "#B5507A"),
        Artist(name: "Raphael", datasetLabel: "Raphael",
               nationality: "Italian", movement: "Renaissance",
               born: "1483", died: "1520", accentColorHex: "#7A8BB5"),
    ]

    /// Tolerant lookup — normalizes underscores/hyphens to spaces, case-insensitive.
    static func artist(fromLabel label: String) -> Artist? {
        let needle = label
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !needle.isEmpty else { return nil }
        return all.first { $0.datasetLabel.lowercased() == needle }
            ?? all.first { $0.name.lowercased() == needle }
    }

    /// Accent color for any artist label, falling back to museum gold.
    static func accentColor(for label: String) -> Color {
        artist(fromLabel: label)?.accentColor ?? .appAccent
    }
}
