//
//  VisionService.swift
//  MuseumMate
//
//  Cloud path: DeepSeek V4 Pro Vision identifies the artwork and returns
//  strict JSON matching the Artwork CodingKeys. Robust against markdown
//  fences and chatty wrappers.
//
// Vision provider : Qwen-VL-Plus (quick identification)
// Platform        : Alibaba DashScope (OpenAI-compatible mode)
// Endpoint        : dashscope-intl.aliyuncs.com/compatible-mode/v1
// Model           : qwen-vl-plus (fast, accurate visual recognition)
//
// Stage 2 full detail is handled by ArtworkDetailService (DeepSeek V4 Pro).
//

import UIKit

/// Result of the Qwen quick-identification pass.
struct QuickIdentification {
    let title: String
    let artist: String
    let confidence: Double
}

final class VisionService {
    // Qwen-VL-Plus — vision-only stage (stage 1 of 3 in the scan pipeline).
    private let qwenEndpoint = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions"
    private let qwenModel    = "qwen-vl-plus"
    private var qwenAPIKey: String { AppConfig.qwenAPIKey }

    /// Minimal identification prompt: return only title, artist, confidence JSON.
    private let qwenVisionPrompt = """
    You are an expert art historian. Look at this artwork image carefully and identify \
    the specific painting or artwork. Respond ONLY with valid JSON — no markdown, \
    no extra text:
    {
      "title": "exact title of the artwork",
      "artist": "full name of the artist",
      "confidence": 0.0 to 1.0
    }
    If you cannot identify the specific work, set title to "Unknown Artwork", \
    artist to "Unknown Artist", and confidence to a low value. Always return valid JSON.
    """

    // DeepSeek V4 Pro — text-only, used for Dashboard quote/trivia/explanations.
    private let endpoint = "https://api.deepseek.com/chat/completions"
    private let model    = "deepseek-v4-pro"
    private var apiKey: String { AppConfig.deepSeekAPIKey }

    // MARK: - Public API

    /// Stage 1 of the scan pipeline: Qwen-VL-Plus identifies the artwork name
    /// from the image. Returns a lightweight QuickIdentification (no details).
    /// Call ArtworkDetailService.generateFullDetail(title:artist:) for stage 3.
    func quickIdentify(imageBase64: String) async throws -> QuickIdentification {
        guard AppConfig.hasValidQwenKey else { throw VisionError.missingAPIKey }
        return try await analyzeImageWithQwen(imageBase64: imageBase64)
    }

    // MARK: - Image encoding

    /// Compresses to JPEG (default quality 0.55) and returns base64 — smaller
    /// payloads identify just as well and cost less.
    static func base64(from image: UIImage, quality: CGFloat = 0.55) -> String? {
        image.jpegData(compressionQuality: quality)?.base64EncodedString()
    }

    // MARK: - Stage 1: Qwen-VL-Plus quick identification

    private func analyzeImageWithQwen(imageBase64: String) async throws -> QuickIdentification {
        guard let url = URL(string: qwenEndpoint) else { throw VisionError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(qwenAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let userContent: [[String: Any]] = [
            ["type": "text", "text": qwenVisionPrompt],
            ["type": "image_url",
             "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]]
        ]
        let messages: [[String: Any]] = [
            ["role": "user", "content": userContent]
        ]
        let body: [String: Any] = [
            "model":       qwenModel,
            "max_tokens":  200,
            "temperature": 0.1,
            "messages":    messages
        ]
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

        let content = try extractContent(from: data)
        return try decodeQuickID(from: content)
    }

    // MARK: - Response parsing

    private func extractContent(from data: Data) throws -> String {
        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw VisionError.emptyResponse }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VisionError.emptyResponse }
        return trimmed
    }

    private func decodeQuickID(from content: String) throws -> QuickIdentification {
        let cleaned = stripMarkdown(content)

        struct Raw: Codable {
            var title: String
            var artist: String
            var confidence: Double
        }

        func tryDecode(_ text: String) -> QuickIdentification? {
            guard let data = text.data(using: .utf8),
                  let raw  = try? JSONDecoder().decode(Raw.self, from: data)
            else { return nil }
            return QuickIdentification(title: raw.title, artist: raw.artist, confidence: raw.confidence)
        }

        if let q = tryDecode(cleaned) { return q }

        if let start = cleaned.firstIndex(of: "{"),
           let end   = cleaned.lastIndex(of: "}"),
           start < end,
           let q = tryDecode(String(cleaned[start...end])) { return q }

        throw VisionError.decodingFailed
    }

    /// Drops ```json / ``` fences the model sometimes wraps JSON in.
    private func stripMarkdown(_ string: String) -> String {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            // Remove the opening fence (and an optional language tag).
            if let firstNewline = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstNewline)...])
            }
        }
        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Text-only daily content (Dashboard)

extension VisionService {
    /// One contemplative quote inspired by the daily painting.
    func generateArtworkQuote(painting: MetObject) async throws -> String {
        let prompt = """
        You are a poet and art philosopher. Write ONE beautiful, contemplative quote \
        (max 35 words) inspired by '\(painting.title)' by \(painting.artistOrUnknown). \
        The quote should evoke the mood and feeling of the work without describing it \
        literally. Return only the quote text, no quotation marks, no attribution.
        """
        // DeepSeek V4 Pro — text generation
        // No image payload for this call
        let text = try await completeText(system: nil, user: prompt, maxTokens: 80, temperature: 0.9)
        return text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'\n "))
    }

    /// A moderate-difficulty multiple-choice question about the painting.
    func generateDailyTrivia(painting: MetObject) async throws -> TriviaQuestion {
        let prompt = """
        Create one multiple-choice trivia question about the artwork '\(painting.title)' \
        by \(painting.artistOrUnknown) (\(painting.objectDate)). Return ONLY valid JSON, no markdown:
        {
          "question": "...",
          "options": ["A", "B", "C", "D"],
          "correctIndex": 0,
          "explanation": "Brief explanation of the correct answer (1-2 sentences)."
        }
        Make it genuinely interesting and educational. Difficulty: moderate.
        """
        // DeepSeek V4 Pro — text generation
        // No image payload for this call
        let text = try await completeText(system: nil, user: prompt, maxTokens: 300, temperature: 0.7)
        return try decodeTrivia(from: text)
    }

    /// Why an art-history event mattered, in 2–3 sentences.
    func generateOnThisDayExplanation(event: ArtHistoryEvent) async throws -> String {
        let prompt = """
        In 2-3 sentences, explain why '\(event.title)' on \(event.dateDescription) was \
        significant in art history. Write as if for an intelligent general audience \
        visiting a museum. Be specific and engaging.
        """
        // DeepSeek V4 Pro — text generation
        // No image payload for this call
        return try await completeText(system: nil, user: prompt, maxTokens: 150, temperature: 0.7)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Shared text completion

    private func completeText(system: String?, user: String, maxTokens: Int, temperature: Double) async throws -> String {
        guard AppConfig.hasValidAPIKey else { throw VisionError.missingAPIKey }
        guard let url = URL(string: "https://api.deepseek.com/chat/completions") else {
            throw VisionError.invalidURL
        }

        var messages: [[String: Any]] = []
        if let system { messages.append(["role": "system", "content": system]) }
        messages.append(["role": "user", "content": user])

        let body: [String: Any] = [
            "model": "deepseek-v4-pro",
            "max_tokens": maxTokens,
            "temperature": temperature,
            "messages": messages
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppConfig.deepSeekAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw VisionError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw VisionError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 429 { throw VisionError.rateLimited }
            throw VisionError.httpError(http.statusCode, "")
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw VisionError.emptyResponse }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VisionError.emptyResponse }
        return trimmed
    }

    private func decodeTrivia(from content: String) throws -> TriviaQuestion {
        let cleaned = stripMarkdown(content)
        let decoder = JSONDecoder()
        if let data = cleaned.data(using: .utf8),
           let trivia = try? decoder.decode(TriviaQuestion.self, from: data) {
            return trivia
        }
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}"),
           start < end {
            let slice = String(cleaned[start...end])
            if let data = slice.data(using: .utf8),
               let trivia = try? decoder.decode(TriviaQuestion.self, from: data) {
                return trivia
            }
        }
        throw VisionError.decodingFailed
    }
}

// MARK: - Errors

enum VisionError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case emptyResponse
    case rateLimited
    case encodingFailed
    case decodingFailed
    case network(String)
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Qwen and DeepSeek API keys in Secrets.plist to identify artworks."
        case .invalidURL:
            return "The identification service address is invalid."
        case .invalidResponse:
            return "The identification service returned an unexpected response."
        case .emptyResponse:
            return "The identification service returned no result. Please try again."
        case .rateLimited:
            return "Too many requests right now. Please wait a moment and try again."
        case .encodingFailed:
            return "Could not prepare the image for identification."
        case .decodingFailed:
            return "Could not read the identification result. Please try again."
        case .network(let detail):
            return "Network error: \(detail)"
        case .httpError(let code, _):
            return "The identification service failed (error \(code))."
        }
    }
}
