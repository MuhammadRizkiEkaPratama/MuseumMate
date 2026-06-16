//
//  ScanViewModel.swift
//  MuseumMate
//
//  Orchestrates the scan pipeline: instant offline style detection, then
//  cloud identification, then persistence. The local style appears in
//  ~100ms so the app feels alive long before DeepSeek responds.
//

import SwiftUI

@MainActor
final class ScanViewModel: ObservableObject {

    enum ScanPhase: Equatable {
        case idle
        case detectingStyle
        case identifyingArtwork
        case complete
        case failed(String)

        var label: String {
            switch self {
            case .idle: return ""
            case .detectingStyle: return "Detecting style…"
            case .identifyingArtwork: return "Identifying artwork…"
            case .complete: return "Done"
            case .failed: return "Couldn't identify"
            }
        }
    }

    @Published var phase: ScanPhase = .idle
    @Published var selectedImage: UIImage?
    @Published var currentResult: ScanResult?
    @Published var localStylePreview: String?
    @Published var localConfidencePreview: Double = 0

    let classifier = ArtStyleClassifierService()
    private let vision = VisionService()

    var isScanning: Bool {
        phase == .detectingStyle || phase == .identifyingArtwork
    }

    // MARK: - Pipeline

    func scan(image: UIImage, store: ScanHistoryStore) async {
        // (a) LOCAL — instant style guess (safe no-op when no model is bundled).
        phase = .detectingStyle
        if let cgImage = image.cgImage {
            await classifier.classify(cgImage: cgImage)
        }
        let localStyle = classifier.detectedStyle
        let localConfidence = classifier.confidence
        localStylePreview = localStyle
        localConfidencePreview = localConfidence

        // Persist the image to disk (full + thumbnail).
        let saved = ImageStore.save(image)

        // (b) CLOUD — precise identification (may fail offline / without a key).
        phase = .identifyingArtwork
        var artwork: Artwork?
        var failureMessage: String?
        do {
            guard let base64 = VisionService.base64(from: image) else {
                throw VisionError.encodingFailed
            }
            artwork = try await vision.identifyArtwork(imageBase64: base64)
        } catch {
            failureMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not reach the identification service. Style detected offline."
        }

        // (c) Always save a result — partial when the cloud call failed.
        let result = ScanResult(
            date: Date(),
            imageFileName: saved.image ?? "",
            thumbnailFileName: saved.thumbnail,
            localStyle: localStyle,
            localConfidence: localConfidence,
            artwork: artwork
        )
        store.save(result)
        currentResult = result

        if artwork == nil, let failureMessage {
            phase = .failed(failureMessage)
            Haptics.notification(.error)
        } else {
            phase = .complete
            Haptics.notification(.success)
        }
    }

    func reset() {
        phase = .idle
        selectedImage = nil
        currentResult = nil
        localStylePreview = nil
        localConfidencePreview = 0
    }
}
