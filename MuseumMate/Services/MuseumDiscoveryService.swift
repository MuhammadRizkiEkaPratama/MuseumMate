//
//  MuseumDiscoveryService.swift
//  MuseumMate
//
//  Finds real museums near a coordinate using the OpenStreetMap Overpass API.
//  Free, no API key required. Falls back to the curated MuseumLibrary when the
//  network is unavailable or no results are found nearby.
//

import Foundation
import CoreLocation

@MainActor
final class MuseumDiscoveryService {

    private let endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter"
    ]

    /// Returns up to `limit` museums within `radiusKm` of the user, sorted by distance.
    func nearbyMuseums(
        near user: CLLocation,
        radiusKm: Double = 50,
        limit: Int = 6
    ) async throws -> [Museum] {
        let lat = user.coordinate.latitude
        let lon = user.coordinate.longitude
        let radiusMeters = Int(radiusKm * 1000)

        // Overpass QL: museums + art galleries as nodes, ways, relations.
        let query = """
        [out:json][timeout:25];
        (
          node["tourism"="museum"](around:\(radiusMeters),\(lat),\(lon));
          way["tourism"="museum"](around:\(radiusMeters),\(lat),\(lon));
          node["tourism"="gallery"](around:\(radiusMeters),\(lat),\(lon));
          way["tourism"="gallery"](around:\(radiusMeters),\(lat),\(lon));
        );
        out center tags;
        """

        var lastError: Error = URLError(.badServerResponse)

        for endpoint in endpoints {
            do {
                let museums = try await fetch(query: query, endpoint: endpoint, user: user)
                if !museums.isEmpty {
                    return Array(museums.prefix(limit))
                }
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    private func fetch(query: String, endpoint: String, user: CLLocation) async throws -> [Museum] {
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8)
        request.timeoutInterval = 25

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)

        let museums: [Museum] = decoded.elements.compactMap { el in
            guard let tags = el.tags,
                  let name = tags["name"], !name.isEmpty else { return nil }
            // Coordinate: node has lat/lon; way/relation has center.
            let coordLat = el.lat ?? el.center?.lat
            let coordLon = el.lon ?? el.center?.lon
            guard let mLat = coordLat, let mLon = coordLon else { return nil }

            let city    = tags["addr:city"] ?? tags["addr:town"] ?? tags["addr:suburb"] ?? ""
            let country = tags["addr:country"] ?? ""
            let website = tags["website"] ?? tags["contact:website"] ?? ""
            let kind    = tags["tourism"] == "gallery" ? "Art gallery" : "Museum"

            return Museum(
                name: name,
                city: city,
                country: country,
                latitude: mLat,
                longitude: mLon,
                description: "\(kind) near your location.",
                iconicWork: "",
                websiteURL: website
            )
        }

        return museums
            .sorted { ($0.distanceKm(from: user) ?? .infinity) < ($1.distanceKm(from: user) ?? .infinity) }
    }
}

// MARK: - Overpass JSON

private struct OverpassResponse: Decodable {
    let elements: [Element]
}

private struct Element: Decodable {
    let lat: Double?
    let lon: Double?
    let center: Center?
    let tags: [String: String]?

    struct Center: Decodable {
        let lat: Double
        let lon: Double
    }
}
