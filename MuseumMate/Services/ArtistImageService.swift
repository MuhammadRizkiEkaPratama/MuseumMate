//
//  ArtistImageService.swift
//  MuseumMate
//
//  Fetches an artist portrait thumbnail URL from the Wikipedia REST API.
//  Uses the /page/summary endpoint which returns a thumbnail.source field.
//  Requires ATS exceptions for en.wikipedia.org and upload.wikimedia.org.
//

import Foundation

final class ArtistImageService {

    private let base = "https://en.wikipedia.org/api/rest_v1/page/summary/"

    /// Returns the portrait image URL string for the given artist name, or nil
    /// if Wikipedia has no thumbnail for that article.
    func fetchPortraitURL(for artistName: String) async -> String? {
        let encoded = artistName
            .replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? artistName
        guard let url = URL(string: base + encoded) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("MuseumMate/1.0 (iOS; contact: riskijambi52@gmail.com)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let thumbnail = json["thumbnail"] as? [String: Any],
              let source = thumbnail["source"] as? String
        else { return nil }

        return source
    }
}
