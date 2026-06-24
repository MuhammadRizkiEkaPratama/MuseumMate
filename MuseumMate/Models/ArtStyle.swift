//
//  ArtStyle.swift
//  MuseumMate
//
//  Artist metadata. The first 12 entries match the ArtistClassifier.mlmodel
//  dataset labels exactly (used for offline Core ML recognition). The
//  remaining entries are discovery-only artists shown in the Artists tab.
//

import SwiftUI

struct Artist: Identifiable {
    let id = UUID()
    let name: String           // display name
    let datasetLabel: String   // exact folder name used in training (empty = discovery only)
    let nationality: String
    let movement: String
    let born: String
    let died: String
    let accentColorHex: String
    var accentColor: Color { Color(hex: accentColorHex) }
}

struct ArtistLibrary {
    // MARK: - All 40 artists

    static let all: [Artist] = coreMLArtists + discoveryArtists

    // 12 Core ML artists — datasetLabel MUST match Create ML folder names exactly.
    static let coreMLArtists: [Artist] = [
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

    // 28 discovery-only artists — shown in the Artists tab, bio loaded from DeepSeek.
    static let discoveryArtists: [Artist] = [
        Artist(name: "Claude Monet", datasetLabel: "Claude Monet",
               nationality: "French", movement: "Impressionism",
               born: "1840", died: "1926", accentColorHex: "#7FC4C8"),
        Artist(name: "Michelangelo", datasetLabel: "Michelangelo",
               nationality: "Italian", movement: "High Renaissance",
               born: "1475", died: "1564", accentColorHex: "#D4A574"),
        Artist(name: "Johannes Vermeer", datasetLabel: "Johannes Vermeer",
               nationality: "Dutch", movement: "Dutch Golden Age",
               born: "1632", died: "1675", accentColorHex: "#4A7BA7"),
        Artist(name: "Caravaggio", datasetLabel: "Caravaggio",
               nationality: "Italian", movement: "Baroque",
               born: "1571", died: "1610", accentColorHex: "#8B4513"),
        Artist(name: "Gustav Klimt", datasetLabel: "Gustav Klimt",
               nationality: "Austrian", movement: "Art Nouveau",
               born: "1862", died: "1918", accentColorHex: "#D4AF37"),
        Artist(name: "Frida Kahlo", datasetLabel: "Frida Kahlo",
               nationality: "Mexican", movement: "Surrealism",
               born: "1907", died: "1954", accentColorHex: "#CC4444"),
        Artist(name: "Wassily Kandinsky", datasetLabel: "Wassily Kandinsky",
               nationality: "Russian", movement: "Abstract Expressionism",
               born: "1866", died: "1944", accentColorHex: "#5B4FCF"),
        Artist(name: "Paul Cézanne", datasetLabel: "Paul Cézanne",
               nationality: "French", movement: "Post-Impressionism",
               born: "1839", died: "1906", accentColorHex: "#8B9467"),
        Artist(name: "Georges Seurat", datasetLabel: "Georges Seurat",
               nationality: "French", movement: "Pointillism",
               born: "1859", died: "1891", accentColorHex: "#4F86C6"),
        Artist(name: "Henri Matisse", datasetLabel: "Henri Matisse",
               nationality: "French", movement: "Fauvism",
               born: "1869", died: "1954", accentColorHex: "#E8A041"),
        Artist(name: "Edvard Munch", datasetLabel: "Edvard Munch",
               nationality: "Norwegian", movement: "Expressionism",
               born: "1863", died: "1944", accentColorHex: "#7B3F7B"),
        Artist(name: "Jackson Pollock", datasetLabel: "Jackson Pollock",
               nationality: "American", movement: "Abstract Expressionism",
               born: "1912", died: "1956", accentColorHex: "#2F4858"),
        Artist(name: "Andy Warhol", datasetLabel: "Andy Warhol",
               nationality: "American", movement: "Pop Art",
               born: "1928", died: "1987", accentColorHex: "#CF4F8A"),
        Artist(name: "Joan Miró", datasetLabel: "Joan Miró",
               nationality: "Spanish", movement: "Surrealism",
               born: "1893", died: "1983", accentColorHex: "#E8541E"),
        Artist(name: "Piet Mondrian", datasetLabel: "Piet Mondrian",
               nationality: "Dutch", movement: "De Stijl",
               born: "1872", died: "1944", accentColorHex: "#1B6FBF"),
        Artist(name: "Eugène Delacroix", datasetLabel: "Eugène Delacroix",
               nationality: "French", movement: "Romanticism",
               born: "1798", died: "1863", accentColorHex: "#8B3B3B"),
        Artist(name: "J.M.W. Turner", datasetLabel: "J.M.W. Turner",
               nationality: "British", movement: "Romanticism",
               born: "1775", died: "1851", accentColorHex: "#D4A021"),
        Artist(name: "Raden Saleh", datasetLabel: "Raden Saleh",
               nationality: "Indonesian", movement: "Romanticism",
               born: "1811", died: "1880", accentColorHex: "#5B8A3C"),
        Artist(name: "Affandi", datasetLabel: "Affandi",
               nationality: "Indonesian", movement: "Expressionism",
               born: "1907", died: "1990", accentColorHex: "#D4622A"),
        Artist(name: "Basuki Abdullah", datasetLabel: "Basuki Abdullah",
               nationality: "Indonesian", movement: "Realism",
               born: "1915", died: "1993", accentColorHex: "#8A6B3C"),
        Artist(name: "Jean-Michel Basquiat", datasetLabel: "Jean-Michel Basquiat",
               nationality: "American", movement: "Neo-Expressionism",
               born: "1960", died: "1988", accentColorHex: "#7F3F1F"),
        Artist(name: "Mark Rothko", datasetLabel: "Mark Rothko",
               nationality: "American", movement: "Abstract Expressionism",
               born: "1903", died: "1970", accentColorHex: "#8B2020"),
        Artist(name: "Edward Hopper", datasetLabel: "Edward Hopper",
               nationality: "American", movement: "Realism",
               born: "1882", died: "1967", accentColorHex: "#4A7F9F"),
        Artist(name: "Georgia O'Keeffe", datasetLabel: "Georgia O'Keeffe",
               nationality: "American", movement: "Modernism",
               born: "1887", died: "1986", accentColorHex: "#9F5F2F"),
        Artist(name: "Katsushika Hokusai", datasetLabel: "Katsushika Hokusai",
               nationality: "Japanese", movement: "Ukiyo-e",
               born: "1760", died: "1849", accentColorHex: "#1A4F8A"),
        Artist(name: "Marc Chagall", datasetLabel: "Marc Chagall",
               nationality: "Belarusian-French", movement: "Modernism",
               born: "1887", died: "1985", accentColorHex: "#6F4FCF"),
        Artist(name: "Hieronymus Bosch", datasetLabel: "Hieronymus Bosch",
               nationality: "Dutch", movement: "Early Netherlandish",
               born: "c. 1450", died: "1516", accentColorHex: "#5F7A3A"),
        Artist(name: "Peter Paul Rubens", datasetLabel: "Peter Paul Rubens",
               nationality: "Flemish", movement: "Baroque",
               born: "1577", died: "1640", accentColorHex: "#C47A2F"),
    ]

    // MARK: - Lookup helpers

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
