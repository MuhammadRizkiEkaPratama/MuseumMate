//
//  ArtHistoryEvent.swift
//  MuseumMate
//
//  "On This Day in Art" — a hand-curated library of notable art-history
//  events, at least five per month.
//

import Foundation

struct ArtHistoryEvent: Identifiable, Codable {
    var id = UUID()
    let month: Int
    let day: Int
    let year: Int
    let title: String           // e.g. "Vincent van Gogh was born"
    let dateDescription: String // e.g. "March 30, 1853"
    let category: EventCategory

    enum EventCategory: String, Codable {
        case birth, death, creation, exhibition, movement, discovery

        var symbol: String {
            switch self {
            case .birth: return "person.crop.circle"
            case .death: return "person.fill.xmark"
            case .creation: return "paintbrush.pointed"
            case .exhibition: return "building.columns"
            case .movement: return "sparkles"
            case .discovery: return "magnifyingglass"
            }
        }

        var label: String { rawValue.capitalized }
    }
}

enum ArtHistoryLibrary {
    static func eventsForToday(_ date: Date = Date()) -> [ArtHistoryEvent] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return all.filter { $0.month == month && $0.day == day }
    }

    private static func e(_ m: Int, _ d: Int, _ y: Int, _ title: String, _ desc: String, _ c: ArtHistoryEvent.EventCategory) -> ArtHistoryEvent {
        ArtHistoryEvent(month: m, day: d, year: y, title: title, dateDescription: desc, category: c)
    }

    static let all: [ArtHistoryEvent] = [
        // January
        e(1, 15, 1759, "The British Museum opened to the public", "January 15, 1759", .exhibition),
        e(1, 19, 1839, "Paul Cézanne was born", "January 19, 1839", .birth),
        e(1, 23, 1832, "Édouard Manet was born", "January 23, 1832", .birth),
        e(1, 23, 1944, "Edvard Munch died", "January 23, 1944", .death),
        e(1, 23, 1989, "Salvador Dalí died", "January 23, 1989", .death),
        e(1, 28, 1912, "Jackson Pollock was born", "January 28, 1912", .birth),
        e(1, 31, 1977, "The Centre Pompidou opened in Paris", "January 31, 1977", .exhibition),

        // February
        e(2, 6, 1918, "Gustav Klimt died", "February 6, 1918", .death),
        e(2, 18, 1564, "Michelangelo Buonarroti died", "February 18, 1564", .death),
        e(2, 20, 1872, "The Metropolitan Museum of Art opened", "February 20, 1872", .exhibition),
        e(2, 22, 1987, "Andy Warhol died", "February 22, 1987", .death),
        e(2, 25, 1841, "Pierre-Auguste Renoir was born", "February 25, 1841", .birth),

        // March
        e(3, 6, 1475, "Michelangelo Buonarroti was born", "March 6, 1475", .birth),
        e(3, 6, 1986, "Georgia O'Keeffe died", "March 6, 1986", .death),
        e(3, 7, 1872, "Piet Mondrian was born", "March 7, 1872", .birth),
        e(3, 14, 1593, "Georges de La Tour was baptized", "March 14, 1593", .birth),
        e(3, 30, 1853, "Vincent van Gogh was born", "March 30, 1853", .birth),
        e(3, 31, 1889, "The Eiffel Tower was completed", "March 31, 1889", .creation),

        // April
        e(4, 6, 1483, "Raphael was born", "April 6, 1483", .birth),
        e(4, 6, 1520, "Raphael died", "April 6, 1520", .death),
        e(4, 8, 1973, "Pablo Picasso died", "April 8, 1973", .death),
        e(4, 15, 1452, "Leonardo da Vinci was born", "April 15, 1452", .birth),
        e(4, 20, 1893, "Joan Miró was born", "April 20, 1893", .birth),
        e(4, 23, 1775, "J.M.W. Turner was born", "April 23, 1775", .birth),
        e(4, 26, 1937, "The bombing of Guernica inspired Picasso's masterpiece", "April 26, 1937", .creation),

        // May
        e(5, 2, 1519, "Leonardo da Vinci died", "May 2, 1519", .death),
        e(5, 11, 1904, "Salvador Dalí was born", "May 11, 1904", .birth),
        e(5, 11, 2000, "Tate Modern opened in London", "May 11, 2000", .exhibition),
        e(5, 17, 1510, "Sandro Botticelli died", "May 17, 1510", .death),
        e(5, 21, 1471, "Albrecht Dürer was born", "May 21, 1471", .birth),

        // June
        e(6, 6, 1599, “Diego Velázquez was baptized”, “June 6, 1599”, .birth),
        e(6, 6, 1755, “The Uffizi Gallery opened to the public in Florence”, “June 6, 1755”, .exhibition),
        e(6, 7, 1848, “Paul Gauguin was born”, “June 7, 1848”, .birth),
        e(6, 8, 1869, “Frank Lloyd Wright was born”, “June 8, 1869”, .birth),
        e(6, 10, 1819, “Gustave Courbet was born”, “June 10, 1819”, .birth),
        e(6, 15, 1888, “Paul Gauguin moved to Pont-Aven, Brittany to paint”, “June 15, 1888”, .movement),
        e(6, 16, 1958, “Frida Kahlo's first posthumous solo exhibition opened in Mexico City”, “June 16, 1958”, .exhibition),
        e(6, 18, 1889, “Van Gogh painted \u{201C}The Starry Night\u{201D}”, “June 18, 1889”, .creation),
        e(6, 28, 1577, “Peter Paul Rubens was born”, “June 28, 1577”, .birth),
        e(6, 29, 1900, “Antoine de Saint-Exupéry, author-illustrator of The Little Prince, was born”, “June 29, 1900”, .birth),

        // July
        e(7, 6, 1907, "Frida Kahlo was born", "July 6, 1907", .birth),
        e(7, 9, 1962, "Warhol's “Campbell's Soup Cans” went on view", "July 9, 1962", .exhibition),
        e(7, 13, 1954, "Frida Kahlo died", "July 13, 1954", .death),
        e(7, 14, 1862, "Gustav Klimt was born", "July 14, 1862", .birth),
        e(7, 15, 1606, "Rembrandt van Rijn was born", "July 15, 1606", .birth),
        e(7, 18, 1610, "Caravaggio died", "July 18, 1610", .death),
        e(7, 19, 1834, "Edgar Degas was born", "July 19, 1834", .birth),
        e(7, 21, 1897, "The Tate Gallery opened in London", "July 21, 1897", .exhibition),
        e(7, 29, 1890, "Vincent van Gogh died", "July 29, 1890", .death),

        // August
        e(8, 6, 1928, "Andy Warhol was born", "August 6, 1928", .birth),
        e(8, 10, 1793, "The Louvre opened as a public museum", "August 10, 1793", .exhibition),
        e(8, 12, 1988, "Jean-Michel Basquiat died", "August 12, 1988", .death),
        e(8, 21, 1911, "The Mona Lisa was stolen from the Louvre", "August 21, 1911", .discovery),
        e(8, 30, 1748, "Jacques-Louis David was born", "August 30, 1748", .birth),

        // September
        e(9, 7, 1860, "Grandma Moses was born", "September 7, 1860", .birth),
        e(9, 8, 1504, "Michelangelo's “David” was unveiled in Florence", "September 8, 1504", .creation),
        e(9, 26, 1791, "Théodore Géricault was born", "September 26, 1791", .birth),
        e(9, 27, 1917, "Edgar Degas died", "September 27, 1917", .death),
        e(9, 29, 1571, "Caravaggio was born", "September 29, 1571", .birth),

        // October
        e(10, 4, 1669, "Rembrandt van Rijn died", "October 4, 1669", .death),
        e(10, 18, 1997, "The Guggenheim Museum Bilbao opened", "October 18, 1997", .exhibition),
        e(10, 21, 1959, "The Solomon R. Guggenheim Museum opened in NYC", "October 21, 1959", .exhibition),
        e(10, 22, 1906, "Paul Cézanne died", "October 22, 1906", .death),
        e(10, 25, 1881, "Pablo Picasso was born", "October 25, 1881", .birth),
        e(10, 31, 1632, "Johannes Vermeer was baptized", "October 31, 1632", .birth),

        // November
        e(11, 3, 1954, "Henri Matisse died", "November 3, 1954", .death),
        e(11, 7, 1929, "The Museum of Modern Art opened in New York", "November 7, 1929", .exhibition),
        e(11, 14, 1840, "Claude Monet was born", "November 14, 1840", .birth),
        e(11, 15, 1887, "Georgia O'Keeffe was born", "November 15, 1887", .birth),
        e(11, 17, 1917, "Auguste Rodin died", "November 17, 1917", .death),
        e(11, 24, 1864, "Henri de Toulouse-Lautrec was born", "November 24, 1864", .birth),

        // December
        e(12, 1, 1986, "The Musée d'Orsay opened in Paris", "December 1, 1986", .exhibition),
        e(12, 5, 1926, "Claude Monet died", "December 5, 1926", .death),
        e(12, 12, 1863, "Edvard Munch was born", "December 12, 1863", .birth),
        e(12, 16, 1866, "Wassily Kandinsky was born", "December 16, 1866", .birth),
        e(12, 16, 1997, "The Getty Center opened in Los Angeles", "December 16, 1997", .exhibition),
        e(12, 22, 1960, "Jean-Michel Basquiat was born", "December 22, 1960", .birth),
        e(12, 31, 1869, "Henri Matisse was born", "December 31, 1869", .birth),
    ]
}
