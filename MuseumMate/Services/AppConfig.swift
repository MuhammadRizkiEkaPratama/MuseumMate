//
//  AppConfig.swift
//  MuseumMate
//
//  Reads secrets without committing them. Add a `Secrets.plist` to the
//  app target (it is gitignored) with a string key `OpenAIAPIKey`, or set
//  the same key in Info.plist for local testing. Never hardcode the key.
//

import Foundation

enum AppConfig {
    /// Clearly-marked placeholder so the app builds before a key is added.
    static let apiKeyPlaceholder = "YOUR_OPENAI_API_KEY"

    /// The OpenAI API key, resolved at runtime from Secrets.plist or Info.plist.
    static var openAIAPIKey: String {
        if let key = value(forKey: "OpenAIAPIKey"), !key.isEmpty {
            return key
        }
        return apiKeyPlaceholder
    }

    static var hasValidAPIKey: Bool {
        let key = openAIAPIKey
        return !key.isEmpty && key != apiKeyPlaceholder
    }

    // MARK: - Lookup

    private static func value(forKey key: String) -> String? {
        if let fromSecrets = secrets?[key] as? String {
            return fromSecrets.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return fromInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static let secrets: [String: Any]? = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return dict
    }()
}
