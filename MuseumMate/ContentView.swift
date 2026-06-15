//
//  ContentView.swift
//  MuseumMate
//
//  The five-tab main shell: Dashboard, Scan, Collection, Memories, Profile.
//  Gallery-appropriate symbols, gold tint, a flat tab bar.
//

import SwiftUI
import UIKit

enum AppTab: Hashable {
    case dashboard, scan, collection, memories, profile
}

struct ContentView: View {
    @State private var selection: AppTab = .dashboard

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(selectedTab: $selection)
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(AppTab.dashboard)

            ScanView()
                .tabItem { Label("Scan", systemImage: "viewfinder.circle") }
                .tag(AppTab.scan)

            CollectionView(selectedTab: $selection)
                .tabItem { Label("Collection", systemImage: "rectangle.stack") }
                .tag(AppTab.collection)

            MemoriesView()
                .tabItem { Label("Memories", systemImage: "photo.on.rectangle.angled") }
                .tag(AppTab.memories)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .tint(Color.appAccent)
        .onChange(of: selection) { _ in
            Haptics.impact(.light)
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
            .environmentObject(MemoriesStore())
            .preferredColorScheme(.dark)
    }
}
