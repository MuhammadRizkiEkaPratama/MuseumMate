//
//  MuseumMateApp.swift
//  MuseumMate
//
//  REQUIRES: firebase-ios-sdk SPM package + GoogleService-Info.plist in project root.
//

import SwiftUI
import FirebaseCore

@main
struct MuseumMateApp: App {

    @StateObject private var auth          = AuthService()
    @StateObject private var profile       = UserProfile()
    @StateObject private var historyStore  = ScanHistoryStore()
    @StateObject private var favoritesStore = FavoritesStore()
    @StateObject private var memoriesStore = MemoriesStore()
    @StateObject private var ambientPlayer = AmbientAudioService()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(profile)
                .environmentObject(historyStore)
                .environmentObject(favoritesStore)
                .environmentObject(memoriesStore)
                .environmentObject(ambientPlayer)
                .preferredColorScheme(.dark)
                .task {
                    historyStore.attach(profile: profile)
                    favoritesStore.connect(to: historyStore)
                }
                // Wire Firestore when auth state changes
                .onChange(of: auth.currentUserUID) { uid in
                    if let uid {
                        historyStore.connectFirestore(uid: uid)
                        memoriesStore.connectFirestore(uid: uid)
                        profile.loadFromFirestore(uid: uid)
                    } else {
                        historyStore.disconnectFirestore()
                        memoriesStore.disconnectFirestore()
                    }
                }
        }
    }
}
