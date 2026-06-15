//
//  ContentView.swift
//  MuseumMate
//
//  The five-tab main shell. Gallery-appropriate symbols, gold tint,
//  a flat tab bar that melts into the gallery wall.
//

import SwiftUI
import UIKit

struct ContentView: View {
    enum Tab: Hashable {
        case explore, scan, history, favorites, profile
    }

    @State private var selection: Tab = .scan

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selection) {
            ExploreView()
                .tabItem { Label("Explore", systemImage: "camera.aperture") }
                .tag(Tab.explore)

            ScanView()
                .tabItem { Label("Scan", systemImage: "viewfinder.circle") }
                .tag(Tab.scan)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)

            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "heart") }
                .tag(Tab.favorites)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        .tint(Color.appAccent)
        .onChange(of: selection) { _ in
            Haptics.tap()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        appearance.shadowColor = .clear   // no separator line

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.iconColor = UIColor(Color.appAccent)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.appAccent)]
        itemAppearance.normal.iconColor = UIColor(Color.appTextMuted)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.appTextMuted)]
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthService())
            .environmentObject(UserProfile())
            .environmentObject(ScanHistoryStore())
            .environmentObject(FavoritesStore())
            .preferredColorScheme(.dark)
    }
}
