//
//  MemoriesViewModel.swift
//  MuseumMate
//
//  Adds museum-visit photos and auto-links them to scans taken around the
//  same time, surfacing the link as a confirmable suggestion.
//

import SwiftUI

@MainActor
final class MemoriesViewModel: ObservableObject {
    @Published var showAddSheet = false
    @Published var showCamera = false
    @Published var showLibrary = false
    @Published var suggestion: LinkSuggestion?

    /// Window for auto-linking a photo to a nearby-in-time scan.
    private let linkWindow: TimeInterval = 2 * 60 * 60

    struct LinkSuggestion: Identifiable {
        let id = UUID()
        let scan: ScanResult
        let memory: MemoryPhoto
    }

    func addPhoto(_ image: UIImage, memoriesStore: MemoriesStore, historyStore: ScanHistoryStore) {
        guard let fileName = ImageStore.saveImage(image) else { return }
        var photo = MemoryPhoto(imageFileName: fileName, dateTaken: Date())

        if let match = nearbyScan(to: photo.dateTaken, in: historyStore) {
            photo.linkedScanResultID = match.id
            photo.linkedScanTitle = match.displayTitle
            memoriesStore.save(photo)
            suggestion = LinkSuggestion(scan: match, memory: photo)
        } else {
            memoriesStore.save(photo)
        }
        Haptics.notification(.success)
    }

    /// Keep the auto-applied link.
    func confirmSuggestion() {
        Haptics.tap()
        suggestion = nil
    }

    /// Undo the auto-applied link.
    func dismissSuggestion(memoriesStore: MemoriesStore) {
        if let suggestion {
            memoriesStore.unlink(memoryID: suggestion.memory.id)
        }
        self.suggestion = nil
    }

    private func nearbyScan(to date: Date, in store: ScanHistoryStore) -> ScanResult? {
        store.scans
            .filter { abs($0.date.timeIntervalSince(date)) <= linkWindow }
            .min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }
}
