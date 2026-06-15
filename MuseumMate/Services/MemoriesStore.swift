//
//  MemoriesStore.swift
//  MuseumMate
//
//  Museum-visit photos persisted to UserDefaults. Image files live in the
//  Documents directory (via ImageStore). Firestore sync is Phase 8 work.
//

import Foundation

@MainActor
final class MemoriesStore: ObservableObject {
    @Published private(set) var memories: [MemoryPhoto] = []

    private let key = "museummate_memories_v1"
    private let defaults = UserDefaults.standard

    // TODO: Firebase — sync memories to Firestore in Phase 8.

    init() {
        load()
    }

    func load() {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([MemoryPhoto].self, from: data)
        else { return }
        memories = decoded.sorted { $0.dateTaken > $1.dateTaken }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(memories) {
            defaults.set(data, forKey: key)
        }
    }

    func save(_ photo: MemoryPhoto) {
        memories.insert(photo, at: 0)
        memories.sort { $0.dateTaken > $1.dateTaken }
        persist()
    }

    func update(_ photo: MemoryPhoto) {
        guard let index = memories.firstIndex(where: { $0.id == photo.id }) else { return }
        memories[index] = photo
        persist()
    }

    func delete(_ photo: MemoryPhoto) {
        memories.removeAll { $0.id == photo.id }
        ImageStore.deleteImage(named: photo.imageFileName)
        persist()
    }

    func link(memoryID: UUID, to scanResultID: UUID, title: String) {
        guard let index = memories.firstIndex(where: { $0.id == memoryID }) else { return }
        memories[index].linkedScanResultID = scanResultID
        memories[index].linkedScanTitle = title
        persist()
    }

    func unlink(memoryID: UUID) {
        guard let index = memories.firstIndex(where: { $0.id == memoryID }) else { return }
        memories[index].linkedScanResultID = nil
        memories[index].linkedScanTitle = nil
        persist()
    }

    var count: Int { memories.count }
}
