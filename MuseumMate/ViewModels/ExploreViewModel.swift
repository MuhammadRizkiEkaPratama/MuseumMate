//
//  ExploreViewModel.swift
//  MuseumMate
//
//  Drives the live Explore overlay: streams camera frames into the Core ML
//  classifier and publishes the current style. "Scan This" runs the full
//  identification pipeline on the latest frame.
//

import SwiftUI
import Combine

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published var currentStyle = "—"
    @Published var currentConfidence: Double = 0
    @Published var permissionDenied = false
    @Published var isScanning = false
    @Published var capturedResult: ScanResult?

    let camera = CameraService()
    let classifier = ArtStyleClassifierService()
    private let vision = VisionService()

    private var isProcessingFrame = false
    private var cancellables = Set<AnyCancellable>()

    var isMLAvailable: Bool { classifier.isMLAvailable }

    init() {
        camera.onFrame = { [weak self] cgImage in
            // Hops to the main actor; classify() then suspends off-main.
            Task { await self?.process(frame: cgImage) }
        }
        camera.$permissionDenied
            .receive(on: RunLoop.main)
            .assign(to: &$permissionDenied)
    }

    // MARK: - Lifecycle

    func start() { camera.start() }
    func stop() { camera.stop() }

    // MARK: - Live classification

    private func process(frame cgImage: CGImage) async {
        guard !isProcessingFrame, !isScanning else { return }
        isProcessingFrame = true
        await classifier.classify(cgImage: cgImage)   // runs off the main actor
        currentStyle = classifier.detectedStyle == "unknown" ? "—" : classifier.detectedStyle
        currentConfidence = classifier.confidence
        isProcessingFrame = false
    }

    // MARK: - Flow A — capture & identify

    func scanCurrentFrame(store: ScanHistoryStore) async {
        guard let image = camera.captureCurrentFrame() else { return }
        isScanning = true
        Haptics.impact(.medium)

        if let cgImage = image.cgImage {
            await classifier.classify(cgImage: cgImage)
        }
        let localStyle = classifier.detectedStyle
        let localConfidence = classifier.confidence

        let saved = ImageStore.save(image)

        var artwork: Artwork?
        do {
            guard let base64 = VisionService.base64(from: image) else {
                throw VisionError.encodingFailed
            }
            artwork = try await vision.identifyArtwork(imageBase64: base64)
        } catch {
            // Offline / no key — still produce a useful result from the local style.
        }

        let result = ScanResult(
            date: Date(),
            imageFileName: saved.image ?? "",
            thumbnailFileName: saved.thumbnail,
            localStyle: localStyle,
            localConfidence: localConfidence,
            artwork: artwork
        )
        store.save(result)
        capturedResult = result
        isScanning = false
        Haptics.notification(artwork == nil ? .error : .success)
    }

    func clearCapture() {
        capturedResult = nil
    }
}
