//
//  FavoritesStore.swift
//  MuseumMate
//
//  A live view onto ScanHistoryStore, surfacing only favorited scans.
//  Updates automatically whenever the history changes.
//

import Foundation
import Combine

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favorites: [ScanResult] = []

    private var cancellable: AnyCancellable?

    // TODO: Firestore — favorites subcollection sync in Phase 7.

    /// Subscribes to the history store and keeps `favorites` in sync.
    func connect(to history: ScanHistoryStore) {
        cancellable = history.$scans
            .map { $0.filter(\.isFavorite) }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] favorited in
                self?.favorites = favorited
            }
    }

    var isEmpty: Bool { favorites.isEmpty }
    var count: Int { favorites.count }
}
