//
//  UnifiedScanViewModel.swift
//  MuseumMate
//
//  Drives the unified Scan tab. It merges the old Explore overlay logic
//  (live camera → Core ML classifier) with the old Scan pipeline
//  (VisionService cloud identification + persistence). One view model now
//  owns the camera, the live style badge, the capture/import scan flows,
//  and the draggable import sheet's logical state.
//

import SwiftUI
import Combine
import Photos
import AudioToolbox

@MainActor
final class UnifiedScanViewModel: ObservableObject {

    // MARK: - Phases & sheet state

    enum ScanPhase: Equatable {
        case idle
        case detectingStyle
        case identifyingArtwork
        case gatheringDetails
        case complete
        case failed(String)

        var label: String {
            switch self {
            case .idle:               return ""
            case .detectingStyle:     return "Detecting artist…"
            case .identifyingArtwork: return "Identifying artwork…"
            case .gatheringDetails:   return "Gathering details…"
            case .complete:           return "Done"
            case .failed:             return "Couldn't identify"
            }
        }
    }

    enum SheetState {
        case collapsed, halfExpanded, fullExpanded
    }

    // MARK: - Live camera

    @Published var detectedArtist = "—"
    @Published var styleConfidence: Double = 0
    @Published var permissionDenied = false
    @Published var cameraIsRunning = false
    @Published var torchOn = false

    // MARK: - Scanning

    @Published var isScanning = false
    @Published var scanPhase: ScanPhase = .idle
    @Published var currentResult: ScanResult?
    @Published var errorMessage: String?
    /// The image currently being scanned via the import path (drives the
    /// full-screen scanning overlay). Nil for camera-frame scans.
    @Published var importPreview: UIImage?

    // MARK: - Sheet

    @Published var sheetState: SheetState = .collapsed

    // MARK: - Collaborators

    let camera = CameraService()
    let classifier = ArtStyleClassifierService()
    let recents = RecentPhotosLoader()
    private let vision = VisionService()
    private let artworkDetail = ArtworkDetailService()

    private var isProcessingFrame = false
    private var isTabActive = false
    private var errorDismissTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    var isMLAvailable: Bool { classifier.isMLAvailable }
    var hasTorch: Bool { camera.hasTorch }

    init() {
        camera.onFrame = { [weak self] cgImage in
            Task { await self?.process(frame: cgImage) }
        }
        camera.$permissionDenied
            .receive(on: RunLoop.main)
            .assign(to: &$permissionDenied)
        camera.$isRunning
            .receive(on: RunLoop.main)
            .assign(to: &$cameraIsRunning)
        camera.$isTorchOn
            .receive(on: RunLoop.main)
            .assign(to: &$torchOn)

        // Pause the camera while the user browses the full photo sheet.
        $sheetState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                if state == .fullExpanded {
                    self.camera.stop()
                } else if self.isTabActive {
                    self.camera.start()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func startCamera() {
        isTabActive = true
        if sheetState != .fullExpanded { camera.start() }
    }

    func stopCamera() {
        isTabActive = false
        camera.stop()
    }

    func toggleTorch() {
        Haptics.tap()
        camera.toggleTorch()
    }

    // MARK: - Live classification

    private func process(frame cgImage: CGImage) async {
        guard !isProcessingFrame, !isScanning else { return }
        isProcessingFrame = true
        await classifier.classify(cgImage: cgImage)   // runs off the main actor
        detectedArtist = classifier.detectedArtist == "unknown" ? "—" : classifier.detectedArtist
        styleConfidence = classifier.artistConfidence
        isProcessingFrame = false
    }

    // MARK: - Flow A — capture the current camera frame & identify

    func scanCurrentFrame(store: ScanHistoryStore) async {
        guard !isScanning, let image = camera.captureCurrentFrame() else { return }
        Haptics.impact(.medium)
        await runPipeline(image: image, isImport: false, store: store)
    }

    // MARK: - Flow A' — identify an imported photo

    func scan(image: UIImage, store: ScanHistoryStore) async {
        guard !isScanning else { return }
        importPreview = image
        Haptics.impact(.medium)
        await runPipeline(image: image, isImport: true, store: store)
    }

    // MARK: - Shared pipeline

    private func runPipeline(image: UIImage, isImport: Bool, store: ScanHistoryStore) async {
        isScanning = true
        errorMessage = nil
        errorDismissTask?.cancel()

        // (a) LOCAL — instant style guess (safe no-op when no model is bundled).
        scanPhase = .detectingStyle
        if let cgImage = image.cgImage {
            await classifier.classify(cgImage: cgImage)
        }
        let localArtist = classifier.detectedArtist
        let localConfidence = classifier.artistConfidence

        // Persist the image to disk (full + thumbnail).
        let saved = ImageStore.save(image)

        // (b) CLOUD stage 1 — Qwen-VL-Plus: name identification (may fail offline).
        scanPhase = .identifyingArtwork
        var artwork: Artwork?
        var failureMessage: String?
        do {
            guard let base64 = VisionService.base64(from: image) else {
                throw VisionError.encodingFailed
            }
            let quickID = try await vision.quickIdentify(imageBase64: base64)

            // (c) CLOUD stage 2 — DeepSeek V4 Pro: full catalog detail.
            scanPhase = .gatheringDetails
            artwork = try await artworkDetail.generateFullDetail(
                title: quickID.title, artist: quickID.artist
            )
        } catch {
            failureMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not reach the identification service. Style detected offline."
        }

        // (c) Always save a result — partial when the cloud call failed.
        let result = ScanResult(
            date: Date(),
            imageFileName: saved.image ?? "",
            thumbnailFileName: saved.thumbnail,
            localArtist: localArtist,
            localConfidence: localConfidence,
            artwork: artwork
        )
        store.save(result)
        currentResult = result
        isScanning = false
        importPreview = nil

        if artwork == nil {
            scanPhase = .failed(failureMessage ?? "Couldn't identify this artwork.")
            errorMessage = failureMessage ?? "Couldn't identify this artwork."
            Haptics.notification(.error)
            SoundEffect.error()
            scheduleErrorDismiss()
        } else {
            scanPhase = .complete
            Haptics.notification(.success)
            SoundEffect.scanSuccess()
        }
    }

    private func scheduleErrorDismiss() {
        errorDismissTask?.cancel()
        errorDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.dismissError() }
        }
    }

    func dismissError() {
        errorDismissTask?.cancel()
        errorMessage = nil
        if case .failed = scanPhase { scanPhase = .idle }
    }

    // MARK: - Navigation reset

    /// Call when the detail screen has consumed the result, so the next scan
    /// starts clean and the live badge resumes.
    func clearResult() {
        currentResult = nil
        scanPhase = .idle
    }
}

// MARK: - Recent photos loader

/// Loads the most recent photo-library thumbnails for the import sheet, and
/// resolves a full-resolution image on demand when one is tapped.
@MainActor
final class RecentPhotosLoader: ObservableObject {

    struct Item: Identifiable {
        let id: String
        let asset: PHAsset
        let thumbnail: UIImage
    }

    @Published var items: [Item] = []
    @Published var authorized = false
    @Published var didRequest = false

    private let imageManager = PHImageManager.default()
    private let limit = 10

    func loadIfNeeded() {
        guard items.isEmpty else { return }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            authorized = true
            fetch()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                Task { @MainActor in
                    guard let self else { return }
                    self.didRequest = true
                    if newStatus == .authorized || newStatus == .limited {
                        self.authorized = true
                        self.fetch()
                    }
                }
            }
        default:
            authorized = false
            didRequest = true
        }
    }

    private func fetch() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let assets = PHAsset.fetchAssets(with: .image, options: options)

        let target = CGSize(width: 200, height: 200)
        let request = PHImageRequestOptions()
        request.deliveryMode = .opportunistic
        request.resizeMode = .fast
        request.isNetworkAccessAllowed = true

        var collected: [Item] = []
        assets.enumerateObjects { asset, _, _ in
            self.imageManager.requestImage(
                for: asset, targetSize: target, contentMode: .aspectFill, options: request
            ) { image, _ in
                guard let image else { return }
                let item = Item(id: asset.localIdentifier, asset: asset, thumbnail: image)
                Task { @MainActor in
                    if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                        self.items[index] = item        // opportunistic upgrade
                    } else {
                        self.items.append(item)
                    }
                }
            }
            collected.append(Item(id: asset.localIdentifier, asset: asset, thumbnail: UIImage()))
        }
    }

    /// Resolve a full-quality image for scanning when a thumbnail is tapped.
    func fullImage(for asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .none

        return await withCheckedContinuation { continuation in
            var resumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // Opportunistic delivery can call back twice; only resume once,
                // and ignore the low-res degraded pass when a full one follows.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded && image != nil { return }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }
}
