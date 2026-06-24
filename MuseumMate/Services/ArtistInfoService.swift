//
//  ArtistInfoService.swift
//  MuseumMate
//
//  Fetches a rich ArtistProfile from DeepSeek V4 Pro. Called once per artist
//  when the user taps an artist card in the Artist Discovery tab.
//

import Foundation

final class ArtistInfoService {

    private let endpoint = "https://api.deepseek.com/chat/completions"
    private let model    = "deepseek-chat"
    private var apiKey: String { AppConfig.deepSeekAPIKey }

    private let systemPrompt = """
    You are an expert art historian and biographer. Given an artist's name, provide \
    a rich profile as valid JSON — no markdown, no extra text:
    {
      "name": "full name",
      "nationality": "e.g. Dutch, French, Spanish",
      "born": "year or date of birth, e.g. 1853",
      "died": "year or date of death, e.g. 1890",
      "movement": "primary art movement, e.g. Post-Impressionism",
      "bio": "A vivid, engaging 2-3 paragraph biography: childhood, artistic development, \
    defining works, legacy. Make the artist feel real and human.",
      "famous_works": [
        "Title of famous work 1 (year)",
        "Title of famous work 2 (year)",
        "Title of famous work 3 (year)"
      ],
      "portrait_url": "",
      "accent_color_hex": "#C9A227"
    }
    portrait_url should always be an empty string (the app fetches it from Wikipedia). \
    Fill every other field completely and thoughtfully.
    """

    func fetchArtistInfo(name: String) async throws -> ArtistProfile {
        guard AppConfig.hasValidAPIKey else { throw VisionError.missingAPIKey }
        guard let url = URL(string: endpoint) else { throw VisionError.invalidURL }

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user",   "content": "Artist: \(name)\n\nProvide the full JSON profile."]
        ]
        let body: [String: Any] = [
            "model":       model,
            "max_tokens":  800,
            "temperature": 0.6,
            "messages":    messages
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw VisionError.encodingFailed
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw VisionError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw VisionError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            print("[DeepSeek] artistInfo HTTP \(http.statusCode): \(bodyText)")
            if http.statusCode == 429 { throw VisionError.rateLimited }
            throw VisionError.httpError(http.statusCode, bodyText)
        }

        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String,
            !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw VisionError.emptyResponse }

        return try decodeProfile(from: content)
    }

    private func decodeProfile(from content: String) throws -> ArtistProfile {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            if let nl = text.firstIndex(of: "\n") { text = String(text[text.index(after: nl)...]) }
        }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        func tryDecode(_ s: String) -> ArtistProfile? {
            guard let d = s.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(ArtistProfile.self, from: d)
        }

        if let p = tryDecode(text) { return p }
        if let start = text.firstIndex(of: "{"),
           let end   = text.lastIndex(of: "}"),
           start < end,
           let p = tryDecode(String(text[start...end])) { return p }

        throw VisionError.decodingFailed
    }
}
