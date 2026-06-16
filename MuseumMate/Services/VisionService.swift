//
//  VisionService.swift
//  MuseumMate
//
//  Cloud path: DeepSeek V4 Pro Vision identifies the artwork and returns
//  strict JSON matching the Artwork CodingKeys. Robust against markdown
//  fences and chatty wrappers.
//
// Vision provider : DeepSeek V4 Pro
// Platform        : platform.deepseek.com
// Docs            : api-docs.deepseek.com
// Model           : deepseek-v4-pro
//                   (flagship reasoning model — highest accuracy
//                    for art identification and explanation)
// Pricing         : ~$2.18/1M input, $8.72/1M output
//                   (still cheaper than GPT-4o at scale)
//

import UIKit

final class VisionService {
    // Stage 2 — reasoning + identification (DeepSeek V4 Pro, text only).
    private let endpoint = "https://api.deepseek.com/chat/completions"
    private let model = "deepseek-v4-pro"
    private var apiKey: String { AppConfig.deepSeekAPIKey }

    // Stage 1 — vision analysis (Qwen-VL). DeepSeek cannot read images, so a
    // vision model acts as the "eyes": it describes the photo in detail, then
    // DeepSeek reasons over that description to identify the work.
    // Provider   : Alibaba DashScope (OpenAI-compatible mode)
    // Endpoint   : dashscope-intl.aliyuncs.com/compatible-mode/v1
    private let qwenEndpoint = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions"
    private let qwenModel = "qwen-vl-max"
    private var qwenAPIKey: String { AppConfig.qwenAPIKey }

    /// Stage 1 prompt: ask Qwen to describe the artwork and guess its identity.
    private let qwenVisionPrompt = """
    You are an expert art historian and visual analyst. Examine this image of an artwork \
    and describe it in rich, concrete detail: the subject and any figures, the composition, \
    colours, lighting, brushwork and technique, mood, and the apparent art style and period. \
    If you recognise the specific painting and its artist, state them explicitly together with \
    your confidence. Your description will be used to identify the exact artwork, so be \
    specific and thorough.
    """

    /// Stage 2 prompt: DeepSeek identifies the work from Qwen's visual analysis.
    private let reasoningSystemPrompt = """
    You are an expert art historian. Based on the visual analysis provided by the user, \
    identify the specific artwork. Respond ONLY with valid JSON — no markdown, no extra text:
    {
      "title": "...",
      "artist": "...",
      "year": "...",
      "medium": "...",
      "style": "...",
      "location": "the museum or gallery currently holding the original",
      "description": "2-3 paragraph rich explanation: history, meaning, technique",
      "fun_facts": ["fact 1", "fact 2", "fact 3"],
      "confidence": 0.0 to 1.0
    }
    Never leave a field empty. If you cannot identify the specific work, set title to \
    "Unknown" and a low confidence, but still fill style, medium, a general description, \
    and fun facts so the result remains useful.
    """

    // MARK: - Public API

    /// Two-stage pipeline: Qwen-VL describes the image (vision), then DeepSeek
    /// reasons over that description to identify the work and write the catalog
    /// entry. Photo → Qwen → visual description → DeepSeek → Artwork JSON.
    func identifyArtwork(imageBase64: String) async throws -> Artwork {
        guard AppConfig.hasValidQwenKey, AppConfig.hasValidAPIKey else {
            throw VisionError.missingAPIKey
        }

        // Stage 1 — vision: Qwen-VL turns the photo into a detailed description.
        let analysis = try await analyzeImageWithQwen(imageBase64: imageBase64)

        // Stage 2 — reasoning: DeepSeek identifies the artwork from the analysis.
        let user = """
        Visual analysis of the artwork:
        \(analysis)

        Identify this artwork and respond with the JSON.
        """
        let content = try await completeText(
            system: reasoningSystemPrompt, user: user, maxTokens: 1200, temperature: 0.3
        )
        return try decodeArtwork(from: content)
    }

    // MARK: - Image encoding

    /// Compresses to JPEG (default quality 0.55) and returns base64 — smaller
    /// payloads identify just as well and cost less.
    static func base64(from image: UIImage, quality: CGFloat = 0.55) -> String? {
        image.jpegData(compressionQuality: quality)?.base64EncodedString()
    }

    // MARK: - Stage 1: Qwen-VL vision analysis

    /// Sends the photo to Qwen-VL and returns a rich textual description that
    /// the DeepSeek stage then reasons over. Uses the same base64 image pipeline.
    private func analyzeImageWithQwen(imageBase64: String) async throws -> String {
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
            "model": qwenModel,
            "max_tokens": 700,
            "temperature": 0.2,
            "messages": messages
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
        return try extractContent(from: data)
    }

    // MARK: - Response parsing

    private func extractContent(from data: Data) throws -> String {
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

    private func decodeArtwork(from content: String) throws -> Artwork {
        let decoder = JSONDecoder()
        let cleaned = stripMarkdown(content)

        // First attempt: direct decode.
        if let data = cleaned.data(using: .utf8),
           let artwork = try? decoder.decode(Artwork.self, from: data) {
            return artwork
        }

        // Fallback: extract the first {...} block and retry.
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}"),
           start < end {
            let slice = String(cleaned[start...end])
            if let data = slice.data(using: .utf8),
               let artwork = try? decoder.decode(Artwork.self, from: data) {
                return artwork
            }
        }

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
