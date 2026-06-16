// Core ML: Artist identification (offline, instant)
// Model: ArtistClassifier.mlmodel
// Classes: 12 artists from Best Artworks dataset
// Trained with Create ML Image Classification

import Vision
import CoreML
import CoreGraphics

final class ArtistClassifierService: ObservableObject {
    @Published var detectedArtist = "unknown"
    @Published var confidence: Double = 0.0
    @Published var isMLAvailable = false

    private var mlModel: VNCoreMLModel?

    init() { loadMLModel() }

    func loadMLModel() {
        guard
            let url = Bundle.main.url(forResource: "ArtistClassifier", withExtension: "mlmodelc"),
            let core = try? MLModel(contentsOf: url),
            let vn = try? VNCoreMLModel(for: core)
        else {
            isMLAvailable = false   // graceful: app still runs without the model
            return
        }
        mlModel = vn
        isMLAvailable = true
    }

    /// Runs classification off the main actor, then publishes results back on MainActor.
    func classify(cgImage: CGImage) async {
        guard let mlModel else { return }

        let request = VNCoreMLRequest(model: mlModel)
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let top = request.results?.first as? VNClassificationObservation else { return }
            let artist = top.identifier.replacingOccurrences(of: "_", with: " ")
            let conf = Double(top.confidence)   // VNConfidence is Float — cast explicitly
            await MainActor.run {
                self.detectedArtist = artist
                self.confidence = conf
            }
        } catch {
            // Ignore; keep the previous values.
        }
    }
}
