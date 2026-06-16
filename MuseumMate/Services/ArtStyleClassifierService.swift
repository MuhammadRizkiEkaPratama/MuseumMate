//
//  ArtStyleClassifierService.swift
//  MuseumMate
//
//  Offline art-style classification via Core ML. Degrades gracefully:
//  if ArtStyleClassifier.mlmodelc is not bundled, isMLAvailable stays
//  false and classify() is a safe no-op — the app never crashes and the
//  DeepSeek cloud path still works.
//

import Vision
import CoreML
import CoreGraphics

final class ArtStyleClassifierService: ObservableObject {
    @Published var detectedStyle = "unknown"
    @Published var confidence: Double = 0.0
    @Published var isMLAvailable = false

    private var mlModel: VNCoreMLModel?

    init() {
        loadMLModel()
    }

    func loadMLModel() {
        guard
            let url = Bundle.main.url(forResource: "ArtStyleClassifier", withExtension: "mlmodelc"),
            let core = try? MLModel(contentsOf: url),
            let vn = try? VNCoreMLModel(for: core)
        else {
            isMLAvailable = false   // graceful: app still runs without the model
            return
        }
        mlModel = vn
        isMLAvailable = true
    }

    /// Runs classification off the main actor (the method is non-isolated, so
    /// `await` from a @MainActor caller hops to the cooperative pool), then
    /// publishes results back on the main actor.
    func classify(cgImage: CGImage) async {
        guard let mlModel else { return }

        let request = VNCoreMLRequest(model: mlModel)
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let top = request.results?.first as? VNClassificationObservation else { return }
            let style = top.identifier.replacingOccurrences(of: "_", with: " ")
            let conf = Double(top.confidence)   // VNConfidence is Float — cast explicitly
            await MainActor.run {
                self.detectedStyle = style
                self.confidence = conf
            }
        } catch {
            // Ignore; keep the previous values.
        }
    }
}
