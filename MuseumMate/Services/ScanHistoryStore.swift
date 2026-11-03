//
//  ScanHistoryStore.swift
//  MuseumMate
//
//  Scan history: UserDefaults (offline cache) + Firestore (cloud sync).
//  REQUIRES: firebase-ios-sdk (FirebaseFirestore, FirebaseFirestoreSwift) SPM packages.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ScanHistoryStore: ObservableObject {
    @Published private(set) var scans: [ScanResult] = []

    private let localKey   = "museummate_scans"
    private let defaults   = UserDefaults.standard
    private let db         = Firestore.firestore()
    private weak var profile: UserProfile?
    private var firestoreListener: ListenerRegistration?
    private var uid: String?

    init() {
        loadFromLocal()
    }

    deinit {
        firestoreListener?.remove()
    }

    /// Call from MuseumMateApp once auth is known.
    func attach(profile: UserProfile) {
        self.profile = profile
    }

    /// Call when user signs in — starts Firestore real-time listener.
    func connectFirestore(uid: String) {
        guard self.uid != uid else { return }
        self.uid = uid
        firestoreListener?.remove()
        firestoreListener = db.collection("users").document(uid)
            .collection("scans")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents, error == nil else { return }
                Task { @MainActor in
                    let decoded: [ScanResult] = docs.compactMap { doc in
                        guard let jsonData = try? JSONSerialization.data(withJSONObject: doc.data()),
                              let result = try? JSONDecoder().decode(ScanResult.self, from: jsonData)
                        else { return nil }
                        return result
                    }
                    self.scans = decoded
                    self.persistLocal()
                    self.profile?.scanCount = decoded.count
                }
            }
    }

    /// Call when user signs out.
    func disconnectFirestore() {
        firestoreListener?.remove()
        firestoreListener = nil
        uid = nil
    }

    // MARK: - Mutations

    func save(_ result: ScanResult) {
        scans.insert(result, at: 0)
        profile?.scanCount = scans.count
        persistLocal()
        if let uid {
            Task { await syncToFirestore(result, uid: uid) }
        }
    }

    func delete(_ result: ScanResult) {
        scans.removeAll { $0.id == result.id }
        profile?.scanCount = scans.count
        ImageStore.delete(result)
        persistLocal()
        if let uid {
            db.collection("users").document(uid)
                .collection("scans").document(result.id.uuidString)
                .delete()
        }
    }

    func toggleFavorite(_ result: ScanResult) {
        guard let index = scans.firstIndex(where: { $0.id == result.id }) else { return }
        scans[index].isFavorite.toggle()
        persistLocal()
        if let uid {
            Task { await syncToFirestore(scans[index], uid: uid) }
        }
    }

    func isFavorite(_ result: ScanResult) -> Bool {
        scans.first { $0.id == result.id }?.isFavorite ?? result.isFavorite
    }

    // MARK: - Local cache

    private func loadFromLocal() {
        guard
            let data = defaults.data(forKey: localKey),
            let decoded = try? JSONDecoder().decode([ScanResult].self, from: data)
        else { return }
        scans = decoded
    }

    private func persistLocal() {
        if let data = try? JSONEncoder().encode(scans) {
            defaults.set(data, forKey: localKey)
        }
    }

    // MARK: - Firestore sync

    private func syncToFirestore(_ result: ScanResult, uid: String) async {
        guard let data = try? JSONEncoder().encode(result),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        try? await db.collection("users").document(uid)
            .collection("scans").document(result.id.uuidString)
            .setData(dict, merge: true)
    }

    // MARK: - Derived

    var uniqueStyleCount: Int {
        Set(scans.map { $0.displayStyle.lowercased() }
            .filter { $0 != "unknown" && !$0.isEmpty }).count
    }

    // MARK: - Clear all local data (use on sign-out or reset)

    func clearLocalData() {
        scans = []
        defaults.removeObject(forKey: localKey)
        profile?.scanCount = 0
    }
}
