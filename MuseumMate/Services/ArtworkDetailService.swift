//
//  ArtworkDetailService.swift
//  MuseumMate
//
//  Stage 3 of the scan pipeline: given a title + artist from Qwen's quick
//  identification, asks DeepSeek V4 Pro to produce the full catalog entry
//  including extended fields introduced in Part 2C.
//

import Foundation

final class ArtworkDetailService {

    private let endpoint = "https://api.deepseek.com/chat/completions"
    private let model    = "deepseek-v4-pro"
    private var apiKey: String { AppConfig.deepSeekAPIKey }

    private let systemPrompt = """
    You are an expert art historian, poet, and cultural guide. Given an artwork title \
    and artist name, produce a comprehensive catalog entry as valid JSON with no markdown \
    and no extra text:
    {
      "title": "exact artwork title",
      "artist": "full artist name",
      "year": "year or approximate date, e.g. 1889",
      "medium": "oil on canvas / watercolour / etc.",
      "style": "art movement label",
      "location": "museum or gallery currently holding the original",
      "description": "2-3 paragraph rich explanation: history, meaning, technique",
      "fun_facts": ["interesting fact 1", "interesting fact 2", "interesting fact 3"],
      "confidence": 0.95,
      "quote": "A poetic or philosophical quote (1-2 sentences) this artwork evokes",
      "creation_story": "How and why this specific artwork was created — circumstances, \
    emotional state, intent, creative process (2-3 sentences)",
      "romantic_line": "A sweet, poetic line to share with someone special while \
    looking at this artwork together (1 sentence)",
      "artist_nationality": "e.g. Dutch, French, Spanish",
      "exhibition_location": "Full museum name and city",
      "exhibition_since": "Year or decade when it entered the collection, e.g. 1941",
      "category": "Painting / Sculpture / Drawing / Print / etc.",
      "art_style": "Specific style label, e.g. Post-Impressionism",
      "creation_time": "When it was made, e.g. June 1889 or 1503–1519",
      "material": "Materials and dimensions, e.g. Oil on linen, 73.7 × 92.1 cm",
      "theme": "Central thematic content, e.g. Night sky, spirituality, nature",
      "genre": "Genre classification, e.g. Post-Impressionist landscape",
      "short_history": "2-sentence summary of the artwork's history and significance",
      "love_poems": [
        "A tender, poetic line inspired by this artwork's mood",
        "A second romantic line referencing the artwork's imagery",
        "A third imaginative line for sharing with someone special"
      ],
      "artist_story": "A brief, human story about the artist's personality and life \
    (2-3 sentences that make the artist feel real)"
    }
    Fill every field completely and thoughtfully. Never leave a field empty — if \
    uncertain, provide a well-informed general answer so the result is still beautiful \
    and useful.
    """

    /// Takes the title and artist identified by Qwen and returns a fully populated
    /// Artwork from DeepSeek V4 Pro's knowledge base.
    func generateFullDetail(title: String, artist: String) async throws -> Artwork {
        guard AppConfig.hasValidAPIKey else { throw VisionError.missingAPIKey }
        guard let url = URL(string: endpoint) else { throw VisionError.invalidURL }

        let userMessage = """
        Title: \(title)
        Artist: \(artist)

        Provide the complete catalog entry JSON.
        """

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user",   "content": userMessage]
        ]
        let body: [String: Any] = [
            "model":       model,
            "max_tokens":  1200,
            "temperature": 0.7,
            "messages":    messages
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
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
            if http.statusCode == 429 { throw VisionError.rateLimited }
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw VisionError.httpError(http.statusCode, bodyText)
        }

        guard
            let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices  = json["choices"] as? [[String: Any]],
            let message  = choices.first?["message"] as? [String: Any],
            let content  = message["content"] as? String,
            !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw VisionError.emptyResponse }

        return try decodeArtwork(from: content)
    }

    // MARK: - Decoding

    private func decodeArtwork(from content: String) throws -> Artwork {
        let cleaned = stripMarkdown(content)
        let decoder = JSONDecoder()

        if let data = cleaned.data(using: .utf8),
           let artwork = try? decoder.decode(Artwork.self, from: data) {
            return artwork
        }

        if let start = cleaned.firstIndex(of: "{"),
           let end   = cleaned.lastIndex(of: "}"),
           start < end {
            let slice = String(cleaned[start...end])
            if let data = slice.data(using: .utf8),
               let artwork = try? decoder.decode(Artwork.self, from: data) {
                return artwork
            }
        }

        throw VisionError.decodingFailed
    }

    private func stripMarkdown(_ string: String) -> String {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            if let firstNewline = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstNewline)...])
            }
        }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
