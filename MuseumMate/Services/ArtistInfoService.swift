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

    // MARK: - Artist search (unknown / regional artists)

    /// Identifies any artist by name — including regional or less-famous ones —
    /// and returns a lightweight Artist struct suitable for the discovery grid.
    /// The caller can then invoke fetchArtistInfo(name:) for a full biography.
    func searchArtist(query: String) async throws -> Artist {
        guard AppConfig.hasValidAPIKey else { throw VisionError.missingAPIKey }
        guard let url = URL(string: endpoint) else { throw VisionError.invalidURL }

        let system = """
        You are an art historian. Given a name or partial name of any visual artist \
        (painter, sculptor, printmaker, etc.) from any country or era, identify them \
        and return basic profile info. Respond ONLY with valid JSON — no markdown:
        {
          "name": "full name",
          "nationality": "e.g. Indonesian",
          "movement": "primary art movement or style",
          "born": "birth year, e.g. 1811",
          "died": "death year or 'present', e.g. 1880",
          "accent_color_hex": "#C9A227"
        }
        If the query does not match any known visual artist, return name as \
        "Artist Not Found" and all other fields as empty strings. \
        Never invent an artist. Pick an accent_color_hex that fits the artist's style/era.
        """
        let messages: [[String: Any]] = [
            ["role": "system", "content": system],
            ["role": "user",   "content": "Search artist: \(query)"]
        ]
        let body: [String: Any] = [
            "model": model, "max_tokens": 200, "temperature": 0.3, "messages": messages
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch { throw VisionError.network(error.localizedDescription) }

        guard let http = response as? HTTPURLResponse else { throw VisionError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 429 { throw VisionError.rateLimited }
            throw VisionError.httpError(http.statusCode, "")
        }
        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw VisionError.emptyResponse }

        return try decodeSearchResult(from: content)
    }

    private func decodeSearchResult(from content: String) throws -> Artist {
        struct SearchResult: Codable {
            var name: String
            var nationality: String
            var movement: String
            var born: String
            var died: String
            var accent_color_hex: String
        }

        let text = stripFences(content)
        func tryDecode(_ s: String) -> SearchResult? {
            guard let d = s.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(SearchResult.self, from: d)
        }

        var result: SearchResult?
        if let r = tryDecode(text) { result = r }
        else if let start = text.firstIndex(of: "{"),
                let end   = text.lastIndex(of: "}"),
                start < end,
                let r = tryDecode(String(text[start...end])) { result = r }

        guard let r = result, r.name != "Artist Not Found", !r.name.isEmpty else {
            throw VisionError.emptyResponse
        }

        return Artist(
            name: r.name,
            datasetLabel: r.name,
            nationality: r.nationality,
            movement: r.movement,
            born: r.born,
            died: r.died,
            accentColorHex: r.accent_color_hex.isEmpty ? "#C9A227" : r.accent_color_hex
        )
    }

    // MARK: - Born-on-your-birthday lookup
    //
    // Two-step: (1) Wikipedia On This Day API gives FACTUAL names of people
    // born on the date; (2) we filter for visual artists; (3) DeepSeek enriches
    // the confirmed name with movement, nationality, and a personal note.
    // Pure DeepSeek is avoided as the primary source because it hallucinates dates.

    func fetchArtistBornOn(month: Int, day: Int) async throws -> BirthdayArtist {
        let monthName = DateFormatter().monthSymbols[safe: month - 1] ?? "\(month)"

        // Step 1: Wikipedia gives us real births for this date.
        if let confirmedName = try? await wikiArtistBornOn(month: month, day: day) {
            // Step 2: Enrich the confirmed name via DeepSeek.
            if let enriched = try? await enrichBirthdayArtist(
                name: confirmedName, month: month, day: day, monthName: monthName
            ) { return enriched }

            // DeepSeek enrichment failed — return minimal data from Wikipedia.
            return BirthdayArtist(
                name: confirmedName,
                nationality: "",
                born: "\(monthName) \(day)",
                died: "",
                movement: "",
                note: "Like you, \(confirmedName) was born on \(monthName) \(day)!"
            )
        }

        // Fallback: DeepSeek with strict date constraint.
        return try await deepSeekBirthdayArtist(
            month: month, day: day, monthName: monthName
        )
    }

    // MARK: Wikipedia "On This Day / Births" — factual, no hallucination

    private struct WikiBirthsResponse: Decodable {
        let births: [WikiBirth]
    }
    private struct WikiBirth: Decodable {
        let text: String
        let year: Int
        let pages: [WikiPage]?
    }
    private struct WikiPage: Decodable {
        let title: String
        let description: String?
    }

    private func wikiArtistBornOn(month: Int, day: Int) async throws -> String? {
        let urlStr = "https://en.wikipedia.org/api/rest_v1/feed/onthisday/births/\(month)/\(day)"
        guard let url = URL(string: urlStr) else { return nil }

        var req = URLRequest(url: url)
        req.setValue("MuseumMate iOS/1.0 (educational)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else { return nil }

        guard let decoded = try? JSONDecoder().decode(WikiBirthsResponse.self, from: data)
        else { return nil }

        // Keywords that identify visual artists vs. politicians / athletes / etc.
        let artistWords = ["painter", "artist", "sculptor", "illustrator",
                           "printmaker", "engraver", "watercolor", "draughtsman",
                           "draftsman", "miniaturist", "muralist", "photographer",
                           "ceramicist", "glassblower", "tapestry"]
        let excludeWords = ["politician", "president", "prime minister",
                            "athlete", "footballer", "basketball", "tennis",
                            "singer", "musician", "composer", "author", "poet",
                            "actor", "actress", "director", "writer"]

        for birth in decoded.births {
            let desc = (birth.pages?.first?.description ?? "").lowercased()
            let text = birth.text.lowercased()
            let combined = desc + " " + text

            let hasArtist = artistWords.contains { combined.contains($0) }
            let notExcluded = !excludeWords.contains { combined.contains($0) }

            if hasArtist && notExcluded {
                // Prefer the clean Wikipedia page title over the raw text.
                return birth.pages?.first?.title ?? extractNameFromText(birth.text)
            }
        }
        return nil
    }

    // Extract "Firstname Lastname" from "1841 – Firstname Lastname, French painter..."
    private func extractNameFromText(_ text: String) -> String {
        var t = text
        // Drop leading "YEAR – " prefix
        if let dashRange = t.range(of: " \u{2013} ") {
            t = String(t[dashRange.upperBound...])
        } else if let dashRange = t.range(of: " - ") {
            t = String(t[dashRange.upperBound...])
        }
        // Take everything before the first comma
        if let comma = t.firstIndex(of: ",") {
            return String(t[..<comma]).trimmingCharacters(in: .whitespaces)
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    // MARK: DeepSeek — enrich a CONFIRMED artist name with bio details

    private func enrichBirthdayArtist(
        name: String, month: Int, day: Int, monthName: String
    ) async throws -> BirthdayArtist? {
        guard AppConfig.hasValidAPIKey else { return nil }
        guard let url = URL(string: endpoint) else { return nil }

        let system = """
        You are an art historian. Return facts about the visual artist "\(name)". \
        Respond ONLY with valid JSON — no markdown, no extra text:
        {
          "name": "\(name)",
          "nationality": "e.g. French",
          "born": "\(monthName) \(day), YEAR",
          "died": "year or date",
          "movement": "primary art movement",
          "note": "One warm sentence telling the user that \(name) was also born on \(monthName) \(day)."
        }
        """
        let userMsg = "Give me facts about \(name), who was born on \(monthName) \(day)."

        let body: [String: Any] = [
            "model": model, "max_tokens": 200, "temperature": 0.3,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": userMsg]
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else { return nil }

        return try? decodeBirthday(from: content)
    }

    // MARK: Pure DeepSeek fallback (only used when Wikipedia is unreachable)

    private func deepSeekBirthdayArtist(
        month: Int, day: Int, monthName: String
    ) async throws -> BirthdayArtist {
        guard AppConfig.hasValidAPIKey else { throw VisionError.missingAPIKey }
        guard let url = URL(string: endpoint) else { throw VisionError.invalidURL }

        let system = """
        You are an art historian. Name ONE famous visual artist ACTUALLY born on \
        \(monthName) \(day) (any year). Verify the date is correct before answering. \
        Respond ONLY with valid JSON — no markdown:
        {
          "name": "full name",
          "nationality": "nationality",
          "born": "\(monthName) \(day), YEAR",
          "died": "year",
          "movement": "art movement",
          "note": "One warm sentence about sharing this birthday."
        }
        """

        let body: [String: Any] = [
            "model": model, "max_tokens": 250, "temperature": 0.2,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": "Artist born on \(monthName) \(day)?"]
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 45
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw VisionError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
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

    // Memberwise init for Wikipedia path (no JSON decoding needed)
    init(name: String, nationality: String, born: String,
         died: String, movement: String, note: String) {
        self.name = name; self.nationality = nationality
        self.born = born; self.died = died
        self.movement = movement; self.note = note
    }

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
