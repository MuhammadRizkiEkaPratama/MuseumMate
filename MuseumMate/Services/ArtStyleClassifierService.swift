// Dual offline classifier:
//   ArtistClassifier.mlmodel  → 12 artists (Create ML, 77% train / 66% val)
//   ArtStyleClassifier.mlpackage → 8 art styles (ViT / HuggingFace)

import Vision
import CoreML
import CoreGraphics

final class ArtStyleClassifierService: ObservableObject {

    // MARK: - Artist
    @Published var detectedArtist: String = "unknown"
    @Published var artistConfidence: Double = 0.0
    @Published var isArtistMLAvailable: Bool = false

    // MARK: - Style
    @Published var detectedStyle: String = "unknown"
    @Published var styleConfidence: Double = 0.0
    @Published var isStyleMLAvailable: Bool = false

    private var artistModel: VNCoreMLModel?
    private var styleModel: VNCoreMLModel?

    init() {
        loadArtistModel()
        loadStyleModel()
    }

    // MARK: - Load

    private func loadArtistModel() {
        guard
            let url  = Bundle.main.url(forResource: "ArtistClassifier", withExtension: "mlmodelc"),
            let core = try? MLModel(contentsOf: url),
            let vn   = try? VNCoreMLModel(for: core)
        else { return }
        artistModel = vn
        isArtistMLAvailable = true
    }

    private func loadStyleModel() {
        // mlpackage compiles to .mlmodelc inside the bundle at build time
        guard
            let url  = Bundle.main.url(forResource: "ArtStyleClassifier", withExtension: "mlmodelc"),
            let core = try? MLModel(contentsOf: url),
            let vn   = try? VNCoreMLModel(for: core)
        else { return }
        styleModel = vn
        isStyleMLAvailable = true
    }

    // MARK: - Classify

    func classify(cgImage: CGImage) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.classifyArtist(cgImage: cgImage) }
            group.addTask { await self.classifyStyle(cgImage: cgImage) }
        }
    }

    private func classifyArtist(cgImage: CGImage) async {
        guard let model = artistModel else { return }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let top = request.results?.first as? VNClassificationObservation else { return }
            let artist = top.identifier.replacingOccurrences(of: "_", with: " ")
            let conf   = Double(top.confidence)   // VNConfidence is Float — cast explicitly
            await MainActor.run {
                self.detectedArtist    = artist
                self.artistConfidence  = conf
            }
        } catch { }
    }

    private func classifyStyle(cgImage: CGImage) async {
        guard let model = styleModel else { return }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let top = request.results?.first as? VNClassificationObservation else { return }
            let style = top.identifier.replacingOccurrences(of: "_", with: " ")
            let conf  = Double(top.confidence)    // VNConfidence is Float — cast explicitly
            await MainActor.run {
                self.detectedStyle    = style
                self.styleConfidence  = conf
            }
        } catch { }
    }

    // MARK: - Convenience

    var isMLAvailable: Bool { isArtistMLAvailable || isStyleMLAvailable }

    /// Best single-line summary for UI display
    var summary: String {
        switch (isArtistMLAvailable, isStyleMLAvailable) {
        case (true, true):
            return "\(detectedArtist) · \(detectedStyle)"
        case (true, false):
            return detectedArtist
        case (false, true):
            return detectedStyle
        default:
            return "unknown"
        }
    }
}
