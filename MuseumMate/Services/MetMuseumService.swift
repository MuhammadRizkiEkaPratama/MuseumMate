//
//  MetMuseumService.swift
//  MuseumMate
//
//  The Metropolitan Museum of Art Collection API (no key required).
//  Picks one deterministic "daily painting" and caches it for the day.
//

import Foundation

enum MetMuseumError: LocalizedError {
    case networkUnavailable
    case noValidObject
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "Couldn't reach the Met Museum. Check your connection."
        case .noValidObject: return "Couldn't find today's painting. Please try again later."
        case .decodingFailed: return "The Met Museum sent an unexpected response."
        }
    }
}

final class MetMuseumService {
    private let base = "https://collectionapi.metmuseum.org/public/collection/v1"
    private let cacheKey = "museummate_daily_painting_v1"
    private let defaults = UserDefaults.standard

    // MARK: - Daily painting

    func fetchDailyPainting() async throws -> MetObject {
        let today = Self.todayString()
        print("[MetMuseumService] fetchDailyPainting() called for \(today)")

        // Return today's cached painting if present.
        if let cached = cachedPainting(for: today) {
            print("[MetMuseumService] cache hit — returning '\(cached.title)'")
            return cached
        }

        print("[MetMuseumService] no cache — fetching highlight IDs from Met API")
        let ids: [Int]
        do {
            ids = try await fetchHighlightIDs()
        } catch {
            print("[MetMuseumService] fetchHighlightIDs error: \(error)")
            throw error
        }
        guard !ids.isEmpty else {
            print("[MetMuseumService] objectIDs array is empty")
            throw MetMuseumError.noValidObject
        }
        print("[MetMuseumService] received \(ids.count) highlight object IDs")

        let seed = Self.dailySeed()
        let startIndex = seed % ids.count

        // Try up to 5 consecutive objects until one has a usable image.
        for offset in 0..<5 {
            let index = (startIndex + offset) % ids.count
            let objectID = ids[index]
            print("[MetMuseumService] trying objectID \(objectID) (offset \(offset))")
            if let object = try? await fetchObjectDetail(id: objectID),
               object.hasValidImage, !object.title.isEmpty {
                print("[MetMuseumService] found: '\(object.title)' by \(object.artistDisplayName)")
                cachePainting(object, for: today)
                return object
            } else {
                print("[MetMuseumService] objectID \(objectID) skipped (no image or empty title)")
            }
        }
        print("[MetMuseumService] all 5 candidates failed — throwing noValidObject")
        throw MetMuseumError.noValidObject
    }

    func fetchObjectDetail(id: Int) async throws -> MetObject {
        guard let url = URL(string: "\(base)/objects/\(id)") else {
            throw MetMuseumError.networkUnavailable
        }
        let data = try await load(url)
        do {
            return try JSONDecoder().decode(MetObject.self, from: data)
        } catch {
            throw MetMuseumError.decodingFailed
        }
    }

    // MARK: - Highlights

    private func fetchHighlightIDs() async throws -> [Int] {
        let urlString = "\(base)/objects?isHighlight=true&hasImages=true"
        print("[MetMuseumService] GET \(urlString)")
        guard let url = URL(string: urlString) else {
            throw MetMuseumError.networkUnavailable
        }
        let data = try await load(url)
        do {
            let result = try JSONDecoder().decode(MetObjectIDs.self, from: data)
            let ids = result.objectIDs ?? []
            print("[MetMuseumService] total highlighted objects: \(result.total), returned IDs: \(ids.count)")
            return ids
        } catch {
            print("[MetMuseumService] decoding objectIDs failed: \(error)")
            throw MetMuseumError.decodingFailed
        }
    }

    // MARK: - Networking

    private func load(_ url: URL) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                print("[MetMuseumService] non-HTTP response from \(url.host ?? url.absoluteString)")
                throw MetMuseumError.networkUnavailable
            }
            guard (200...299).contains(http.statusCode) else {
                print("[MetMuseumService] HTTP \(http.statusCode) from \(url.host ?? url.absoluteString)")
                throw MetMuseumError.networkUnavailable
            }
            return data
        } catch let error as MetMuseumError {
            throw error
        } catch {
            print("[MetMuseumService] network error: \(error.localizedDescription)")
            throw MetMuseumError.networkUnavailable
        }
    }

    // MARK: - Cache

    private struct CachedPainting: Codable {
        let dateString: String
        let object: MetObject
    }

    private func cachedPainting(for today: String) -> MetObject? {
        guard
            let data = defaults.data(forKey: cacheKey),
            let cached = try? JSONDecoder().decode(CachedPainting.self, from: data),
            cached.dateString == today
        else { return nil }
        return cached.object
    }

    private func cachePainting(_ object: MetObject, for today: String) {
        let payload = CachedPainting(dateString: today, object: object)
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Date helpers

    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    /// Deterministic per-day seed derived from yyyyMMdd.
    static func dailySeed() -> Int {
        Int(todayString()) ?? 20240101
    }
}
