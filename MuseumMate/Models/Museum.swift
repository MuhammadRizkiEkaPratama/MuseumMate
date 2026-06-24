//
//  Museum.swift
//  MuseumMate
//
//  A small world atlas of famous museums with real coordinates, used by
//  the Dashboard "near you" section.
//

import Foundation
import CoreLocation

struct Museum: Identifiable {
    let id = UUID()
    let name: String
    let city: String
    let country: String
    let latitude: Double
    let longitude: Double
    let description: String
    let iconicWork: String
    let websiteURL: String

    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }

    /// Distance in kilometers from a user location, or nil if unknown.
    func distanceKm(from user: CLLocation?) -> Double? {
        guard let user else { return nil }
        return user.distance(from: location) / 1000.0
    }

    /// "2.3 km away" / "1,240 km away"
    static func formattedDistance(_ km: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = km < 10 ? 1 : 0
        let value = formatter.string(from: NSNumber(value: km)) ?? "\(Int(km))"
        return "\(value) km away"
    }
}

enum MuseumLibrary {
    /// Nearest `count` museums to the user; if no location, the famous fallback.
    static func nearest(to user: CLLocation?, count: Int = 3) -> [Museum] {
        guard let user else { return Array(famousFallback.prefix(5)) }
        return all
            .sorted { ($0.distanceKm(from: user) ?? .infinity) < ($1.distanceKm(from: user) ?? .infinity) }
            .prefix(count)
            .map { $0 }
    }

    static let famousFallback: [Museum] = Array(all.prefix(5))

    static let all: [Museum] = [
        Museum(name: "Louvre", city: "Paris", country: "France", latitude: 48.8606, longitude: 2.3376,
               description: "The world's most-visited museum, set in a former royal palace.",
               iconicWork: "the Mona Lisa", websiteURL: "https://www.louvre.fr/en"),
        Museum(name: "The Metropolitan Museum of Art", city: "New York", country: "USA", latitude: 40.7794, longitude: -73.9632,
               description: "America's largest art museum, spanning 5,000 years of culture.",
               iconicWork: "Washington Crossing the Delaware", websiteURL: "https://www.metmuseum.org"),
        Museum(name: "Uffizi Gallery", city: "Florence", country: "Italy", latitude: 43.7687, longitude: 11.2553,
               description: "A Renaissance treasure house on the banks of the Arno.",
               iconicWork: "The Birth of Venus", websiteURL: "https://www.uffizi.it/en"),
        Museum(name: "Museo del Prado", city: "Madrid", country: "Spain", latitude: 40.4138, longitude: -3.6921,
               description: "Spain's national art museum and home of the Spanish masters.",
               iconicWork: "Las Meninas", websiteURL: "https://www.museodelprado.es/en"),
        Museum(name: "The British Museum", city: "London", country: "UK", latitude: 51.5194, longitude: -0.1270,
               description: "Two million years of human history under one roof.",
               iconicWork: "the Rosetta Stone", websiteURL: "https://www.britishmuseum.org"),
        Museum(name: "Musée d'Orsay", city: "Paris", country: "France", latitude: 48.8600, longitude: 2.3266,
               description: "Impressionist masterpieces in a grand former railway station.",
               iconicWork: "Starry Night Over the Rhône", websiteURL: "https://www.musee-orsay.fr/en"),
        Museum(name: "Centre Pompidou", city: "Paris", country: "France", latitude: 48.8606, longitude: 2.3522,
               description: "Europe's largest collection of modern and contemporary art.",
               iconicWork: "works by Kandinsky", websiteURL: "https://www.centrepompidou.fr/en"),
        Museum(name: "Museum of Modern Art", city: "New York", country: "USA", latitude: 40.7614, longitude: -73.9776,
               description: "The defining collection of modern art, from Cézanne to Warhol.",
               iconicWork: "The Starry Night", websiteURL: "https://www.moma.org"),
        Museum(name: "Solomon R. Guggenheim", city: "New York", country: "USA", latitude: 40.7830, longitude: -73.9590,
               description: "Frank Lloyd Wright's spiraling temple to modern art.",
               iconicWork: "works by Kandinsky", websiteURL: "https://www.guggenheim.org"),
        Museum(name: "Whitney Museum of American Art", city: "New York", country: "USA", latitude: 40.7396, longitude: -74.0089,
               description: "The premier collection of 20th-century American art.",
               iconicWork: "works by Edward Hopper", websiteURL: "https://whitney.org"),
        Museum(name: "State Hermitage Museum", city: "St Petersburg", country: "Russia", latitude: 59.9398, longitude: 30.3146,
               description: "An imperial collection inside the Winter Palace.",
               iconicWork: "Return of the Prodigal Son", websiteURL: "https://www.hermitagemuseum.org"),
        Museum(name: "The National Gallery", city: "London", country: "UK", latitude: 51.5089, longitude: -0.1283,
               description: "Western European painting from the 13th to 19th centuries.",
               iconicWork: "Sunflowers", websiteURL: "https://www.nationalgallery.org.uk"),
        Museum(name: "Tate Modern", city: "London", country: "UK", latitude: 51.5076, longitude: -0.0994,
               description: "Modern and contemporary art in a former power station.",
               iconicWork: "works by Rothko", websiteURL: "https://www.tate.org.uk"),
        Museum(name: "Rijksmuseum", city: "Amsterdam", country: "Netherlands", latitude: 52.3600, longitude: 4.8852,
               description: "The Dutch Golden Age in all its glory.",
               iconicWork: "The Night Watch", websiteURL: "https://www.rijksmuseum.nl/en"),
        Museum(name: "Vatican Museums", city: "Vatican City", country: "Vatican City", latitude: 41.9065, longitude: 12.4536,
               description: "Papal collections culminating in the Sistine Chapel.",
               iconicWork: "the Sistine Chapel ceiling", websiteURL: "https://www.museivaticani.va"),
        Museum(name: "Art Institute of Chicago", city: "Chicago", country: "USA", latitude: 41.8796, longitude: -87.6237,
               description: "Home to an iconic Impressionist and modern collection.",
               iconicWork: "American Gothic", websiteURL: "https://www.artic.edu"),
        Museum(name: "Guggenheim Museum Bilbao", city: "Bilbao", country: "Spain", latitude: 43.2687, longitude: -2.9340,
               description: "Frank Gehry's titanium landmark of contemporary art.",
               iconicWork: "Puppy by Jeff Koons", websiteURL: "https://www.guggenheim-bilbao.eus/en"),
        Museum(name: "Smithsonian American Art Museum", city: "Washington", country: "USA", latitude: 38.8979, longitude: -77.0228,
               description: "The nation's collection of American art.",
               iconicWork: "works by Edward Hopper", websiteURL: "https://americanart.si.edu"),
        Museum(name: "National Palace Museum", city: "Taipei", country: "Taiwan", latitude: 25.1023, longitude: 121.5485,
               description: "The world's finest collection of Chinese imperial art.",
               iconicWork: "the Jadeite Cabbage", websiteURL: "https://www.npm.gov.tw/en"),
        Museum(name: "Tokyo National Museum", city: "Tokyo", country: "Japan", latitude: 35.7188, longitude: 139.7765,
               description: "Japan's oldest and largest museum of national treasures.",
               iconicWork: "samurai armor and ukiyo-e", websiteURL: "https://www.tnm.jp/?lang=en"),
        Museum(name: "National Museum of China", city: "Beijing", country: "China", latitude: 39.9046, longitude: 116.3976,
               description: "Five thousand years of Chinese history and art.",
               iconicWork: "ancient bronzes", websiteURL: "https://en.chnmuseum.cn"),
        Museum(name: "Seoul Museum of Art", city: "Seoul", country: "South Korea", latitude: 37.5640, longitude: 126.9737,
               description: "Korea's leading civic museum of modern art.",
               iconicWork: "works by Nam June Paik", websiteURL: "https://sema.seoul.go.kr/en"),
        Museum(name: "National Gallery of Australia", city: "Canberra", country: "Australia", latitude: -35.3009, longitude: 149.1369,
               description: "Australia's flagship collection of national and global art.",
               iconicWork: "Blue Poles by Jackson Pollock", websiteURL: "https://nga.gov.au"),
        Museum(name: "Pinacoteca di Brera", city: "Milan", country: "Italy", latitude: 45.4719, longitude: 9.1880,
               description: "Northern Italy's great collection of Italian painting.",
               iconicWork: "The Kiss by Hayez", websiteURL: "https://pinacotecabrera.org/en"),
        Museum(name: "Alte Pinakothek", city: "Munich", country: "Germany", latitude: 48.1485, longitude: 11.5700,
               description: "One of the oldest galleries of Old Master paintings.",
               iconicWork: "Dürer's Self-Portrait", websiteURL: "https://www.pinakothek.de/en"),
        Museum(name: "Kunsthistorisches Museum", city: "Vienna", country: "Austria", latitude: 48.2038, longitude: 16.3617,
               description: "The Habsburg imperial collection of fine art.",
               iconicWork: "The Tower of Babel by Bruegel", websiteURL: "https://www.khm.at/en"),
        Museum(name: "LACMA", city: "Los Angeles", country: "USA", latitude: 34.0639, longitude: -118.3592,
               description: "The largest art museum in the western United States.",
               iconicWork: "Urban Light by Chris Burden", websiteURL: "https://www.lacma.org"),
        Museum(name: "Getty Center", city: "Los Angeles", country: "USA", latitude: 34.0780, longitude: -118.4741,
               description: "European art on a hilltop campus above Los Angeles.",
               iconicWork: "Irises by Van Gogh", websiteURL: "https://www.getty.edu"),
        Museum(name: "Singapore Art Museum", city: "Singapore", country: "Singapore", latitude: 1.2966, longitude: 103.8520,
               description: "Southeast Asia's leading contemporary art museum.",
               iconicWork: "regional contemporary art", websiteURL: "https://www.singaporeartmuseum.sg"),
        Museum(name: "National Museum of Indonesia", city: "Jakarta", country: "Indonesia", latitude: -6.1769, longitude: 106.8222,
               description: "Indonesia's foremost museum of art and antiquities.",
               iconicWork: "ancient Hindu-Buddhist sculpture", websiteURL: "https://www.museumnasional.or.id"),
        Museum(name: "Museum MACAN", city: "Jakarta", country: "Indonesia", latitude: -6.2127, longitude: 106.8024,
               description: "Indonesia's premier museum of modern and contemporary art in Nusantara.",
               iconicWork: "works by Indonesian contemporary masters", websiteURL: "https://www.museummacan.org"),
        Museum(name: "Galeri Nasional Indonesia", city: "Jakarta", country: "Indonesia", latitude: -6.1731, longitude: 106.8294,
               description: "The national gallery of Indonesian fine art, housed in a colonial-era building.",
               iconicWork: "paintings by Raden Saleh and Affandi", websiteURL: "https://galeri-nasional.or.id"),
        Museum(name: "Museum Affandi", city: "Yogyakarta", country: "Indonesia", latitude: -7.7838, longitude: 110.4060,
               description: "The studio-home of Indonesia's greatest expressionist painter, Affandi.",
               iconicWork: "self-portraits by Affandi", websiteURL: "https://www.museumaffandi.com"),
        Museum(name: "Museum Ullen Sentalu", city: "Yogyakarta", country: "Indonesia", latitude: -7.7542, longitude: 110.3671,
               description: "A living museum of Javanese culture, batik, and royal court art.",
               iconicWork: "royal Javanese batik collections", websiteURL: "https://www.ullensentalu.com"),
        Museum(name: "Museum Seni Rupa dan Keramik", city: "Jakarta", country: "Indonesia", latitude: -6.1342, longitude: 106.8131,
               description: "Jakarta's fine arts and ceramics museum in a restored Dutch colonial building.",
               iconicWork: "Indonesian ceramics and fine art", websiteURL: "https://museumjakarta.com"),
        Museum(name: "Museum Negeri Jambi", city: "Jambi", country: "Indonesia", latitude: -1.6036, longitude: 103.6050,
               description: "Jambi Province's cultural museum, home to Melayu artifacts and regional art.",
               iconicWork: "Melayu Jambi cultural artifacts", websiteURL: "https://www.kebudayaan.kemdikbud.go.id"),
        Museum(name: "Museum Batik Pekalongan", city: "Pekalongan", country: "Indonesia", latitude: -6.8893, longitude: 109.6714,
               description: "The dedicated museum of batik — Indonesia's UNESCO-listed textile art.",
               iconicWork: "UNESCO batik collections", websiteURL: "https://museumbatikpekalongan.info"),
        Museum(name: "Taman Budaya Raden Saleh", city: "Semarang", country: "Indonesia", latitude: -6.9932, longitude: 110.4203,
               description: "Central Java's cultural arts centre named after pioneer painter Raden Saleh.",
               iconicWork: "regional Javanese fine art", websiteURL: "https://www.kebudayaan.kemdikbud.go.id"),
    ]
}
