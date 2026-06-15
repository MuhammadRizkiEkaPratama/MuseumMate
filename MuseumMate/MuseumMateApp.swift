//
//  MuseumMateApp.swift
//  MuseumMate
//

import SwiftUI

@main
struct MuseumMateApp: App {
    // FirebaseApp.configure() and environment objects arrive in Phase 1.
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)   // museum theme is dark-only
        }
    }
}
