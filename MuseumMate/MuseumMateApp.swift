//
//  MuseumMateApp.swift
//  MuseumMate
//

import SwiftUI

@main
struct MuseumMateApp: App {
    // TODO: Firebase — FirebaseApp.configure() goes here in Phase 7.

    @StateObject private var auth = AuthService()
    @StateObject private var profile = UserProfile()
    @StateObject private var historyStore = ScanHistoryStore()
    @StateObject private var favoritesStore = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(profile)
                .environmentObject(historyStore)
                .environmentObject(favoritesStore)
                .preferredColorScheme(.dark)   // museum theme is dark-only
                .task {
                    historyStore.attach(profile: profile)
                    favoritesStore.connect(to: historyStore)
                }
        }
    }
}
