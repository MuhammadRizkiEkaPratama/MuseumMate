//
//  ScanHistoryStore.swift
//  MuseumMate
//
//  Scan history persisted to UserDefaults, newest first. Firestore sync
//  is deferred to Phase 7.
//

import Foundation
import Combine

@MainActor
final class ScanHistoryStore: ObservableObject {
    @Published private(set) var scans: [ScanResult] = []

    private let key = "museummate_scans"
    private let defaults = UserDefaults.standard
    private weak var profile: UserProfile?

    // TODO: Firestore — var firestoreUID: String? and Firestore.firestore() in Phase 7.

    init() {
        load()
    }

    /// Wires the user profile so scan counts stay in sync.
    func attach(profile: UserProfile) {
        self.profile = profile
    }

    // MARK: - Load / persist

    func load() {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([ScanResult].self, from: data)
        else { return }
        scans = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(scans) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - Mutations

    func save(_ result: ScanResult) {
        scans.insert(result, at: 0)
        profile?.scanCount = scans.count
        persist()
        // TODO: Firestore — syncToFirestore(result) in Phase 7.
    }

    func delete(_ result: ScanResult) {
        scans.removeAll { $0.id == result.id }
        profile?.scanCount = scans.count
        ImageStore.delete(result)
        persist()
        // TODO: Firestore — delete document result.id.uuidString in Phase 7.
    }

    func toggleFavorite(_ result: ScanResult) {
        guard let index = scans.firstIndex(where: { $0.id == result.id }) else { return }
        scans[index].isFavorite.toggle()
        persist()
        // TODO: Firestore — sync the updated favorite flag in Phase 7.
    }

    func isFavorite(_ result: ScanResult) -> Bool {
        scans.first { $0.id == result.id }?.isFavorite ?? result.isFavorite
    }

    // MARK: - Derived

    var uniqueStyleCount: Int {
        Set(scans.map { $0.displayStyle.lowercased() }
            .filter { $0 != "unknown" && !$0.isEmpty }).count
    }
}
