//
//  MemoriesStore.swift
//  MuseumMate
//
//  Museum-visit photos: UserDefaults (offline) + Firestore (cloud sync).
//  REQUIRES: firebase-ios-sdk (FirebaseFirestore) SPM packages.
//

import Foundation
import FirebaseFirestore

@MainActor
final class MemoriesStore: ObservableObject {
    @Published private(set) var memories: [MemoryPhoto] = []

    private let localKey = "museummate_memories_v1"
    private let defaults = UserDefaults.standard
    private let db       = Firestore.firestore()
    private var uid: String?
    private var firestoreListener: ListenerRegistration?

    init() {
        loadFromLocal()
    }

    deinit {
        firestoreListener?.remove()
    }

    func connectFirestore(uid: String) {
        guard self.uid != uid else { return }
        self.uid = uid
        firestoreListener?.remove()
        firestoreListener = db.collection("users").document(uid)
            .collection("memories")
            .order(by: "dateTaken", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents, error == nil else { return }
                Task { @MainActor in
                    let decoded = docs.compactMap { doc -> MemoryPhoto? in
                        guard let data = try? JSONSerialization.data(withJSONObject: doc.data()),
                              let mem = try? JSONDecoder().decode(MemoryPhoto.self, from: data)
                        else { return nil }
                        return mem
                    }
                    self.memories = decoded.sorted { $0.dateTaken > $1.dateTaken }
                    self.persistLocal()
                }
            }
    }

    func disconnectFirestore() {
        firestoreListener?.remove()
        firestoreListener = nil
        uid = nil
    }

    // MARK: - Mutations

    func save(_ photo: MemoryPhoto) {
        memories.insert(photo, at: 0)
        memories.sort { $0.dateTaken > $1.dateTaken }
        persistLocal()
        if let uid { Task { await syncToFirestore(photo, uid: uid) } }
    }

    func update(_ photo: MemoryPhoto) {
        guard let index = memories.firstIndex(where: { $0.id == photo.id }) else { return }
        memories[index] = photo
        persistLocal()
        if let uid { Task { await syncToFirestore(photo, uid: uid) } }
    }

    func delete(_ photo: MemoryPhoto) {
        memories.removeAll { $0.id == photo.id }
        ImageStore.deleteImage(named: photo.imageFileName)
        persistLocal()
        if let uid {
            db.collection("users").document(uid)
                .collection("memories").document(photo.id.uuidString)
                .delete()
        }
    }

    func link(memoryID: UUID, to scanResultID: UUID, title: String) {
        guard let index = memories.firstIndex(where: { $0.id == memoryID }) else { return }
        memories[index].linkedScanResultID = scanResultID
        memories[index].linkedScanTitle = title
        persistLocal()
        if let uid { Task { await syncToFirestore(memories[index], uid: uid) } }
    }

    func unlink(memoryID: UUID) {
        guard let index = memories.firstIndex(where: { $0.id == memoryID }) else { return }
        memories[index].linkedScanResultID = nil
        memories[index].linkedScanTitle = nil
        persistLocal()
        if let uid { Task { await syncToFirestore(memories[index], uid: uid) } }
    }

    // MARK: - Local cache

    private func loadFromLocal() {
        guard
            let data = defaults.data(forKey: localKey),
            let decoded = try? JSONDecoder().decode([MemoryPhoto].self, from: data)
        else { return }
        memories = decoded.sorted { $0.dateTaken > $1.dateTaken }
    }

    private func persistLocal() {
        if let data = try? JSONEncoder().encode(memories) {
            defaults.set(data, forKey: localKey)
        }
    }

    // MARK: - Firestore

    private func syncToFirestore(_ photo: MemoryPhoto, uid: String) async {
        guard let data = try? JSONEncoder().encode(photo),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        try? await db.collection("users").document(uid)
            .collection("memories").document(photo.id.uuidString)
            .setData(dict, merge: true)
    }

    func clearLocalData() {
        memories = []
        defaults.removeObject(forKey: localKey)
    }

    var count: Int { memories.count }
}
