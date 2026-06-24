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

    // MARK: - Born-on-your-birthday lookup

    /// Asks DeepSeek which famous painter was born on the given month/day.
    /// Used by the Artists tab to surface a master who shares the user's birthday.
    func fetchArtistBornOn(month: Int, day: Int) async throws -> BirthdayArtist {
        guard AppConfig.hasValidAPIKey else { throw VisionError.missingAPIKey }
        guard let url = URL(string: endpoint) else { throw VisionError.invalidURL }

        let monthName = DateFormatter().monthSymbols[safe: month - 1] ?? "\(month)"
        let system = """
        You are an art historian. Name ONE famous painter or visual artist born on the \
        given calendar date (month and day, any year). Prefer the most renowned artist. \
        Respond ONLY with valid JSON — no markdown, no extra text:
        {
          "name": "full name",
          "nationality": "e.g. French",
          "born": "full birth date, e.g. November 14, 1840",
          "died": "death year or date, e.g. 1926",
          "movement": "primary art movement",
          "note": "One warm sentence telling the user this artist shares their birthday."
        }
        Always return a real artist for the date. Never leave a field empty.
        """
        let user = "Birthday: \(monthName) \(day). Which famous artist was born on this day?"

        let messages: [[String: Any]] = [
            ["role": "system", "content": system],
            ["role": "user",   "content": user]
        ]
        let body: [String: Any] = [
            "model":       model,
            "max_tokens":  300,
            "temperature": 0.5,
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
            print("[DeepSeek] birthday HTTP \(http.statusCode): \(bodyText)")
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

        return try decodeBirthday(from: content)
    }

    private func decodeBirthday(from content: String) throws -> BirthdayArtist {
        let text = stripFences(content)
        func tryDecode(_ s: String) -> BirthdayArtist? {
            guard let d = s.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(BirthdayArtist.self, from: d)
        }
        if let b = tryDecode(text) { return b }
        if let start = text.firstIndex(of: "{"),
           let end   = text.lastIndex(of: "}"),
           start < end,
           let b = tryDecode(String(text[start...end])) { return b }
        throw VisionError.decodingFailed
    }

    private func stripFences(_ content: String) -> String {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            if let nl = text.firstIndex(of: "\n") { text = String(text[text.index(after: nl)...]) }
        }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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

// MARK: - Birthday artist

/// A famous artist who shares the user's birthday, returned by DeepSeek.
struct BirthdayArtist: Codable {
    var name: String
    var nationality: String
    var born: String
    var died: String
    var movement: String
    var note: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name        = (try? c.decode(String.self, forKey: .name))        ?? ""
        nationality = (try? c.decode(String.self, forKey: .nationality)) ?? ""
        born        = (try? c.decode(String.self, forKey: .born))        ?? ""
        died        = (try? c.decode(String.self, forKey: .died))        ?? ""
        movement    = (try? c.decode(String.self, forKey: .movement))    ?? ""
        note        = (try? c.decode(String.self, forKey: .note))        ?? ""
    }

    /// Builds an `Artist` so the existing bio sheet can present this person.
    func asArtist(accentHex: String = "#C9A227") -> Artist {
        Artist(name: name, datasetLabel: name, nationality: nationality,
               movement: movement, born: born, died: died, accentColorHex: accentHex)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
