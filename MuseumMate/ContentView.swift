//
//  ContentView.swift
//  MuseumMate
//
//  Five-tab main shell with a custom floating gold tab bar.
//  Tabs: Dashboard · Scan · Art Pieces · Artists · Profile
//

import SwiftUI
import AudioToolbox

enum AppTab: Hashable {
    case dashboard, scan, collection, artists, profile
}

struct ContentView: View {
    @State private var selection: AppTab = .dashboard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content — one view per tab, stable in the ZStack.
            Group {
                switch selection {
                case .dashboard:
                    DashboardView(selectedTab: $selection)
                case .scan:
                    UnifiedScanView()
                case .collection:
                    CollectionView(selectedTab: $selection)
                case .artists:
                    ArtistDiscoveryView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Push content above the floating bar.
            .padding(.bottom, 90)

            // Floating tab bar
            CustomTabBar(selection: $selection)
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color.appBackground.ignoresSafeArea())
        .onChange(of: selection) { _ in
            SoundEffect.tabChange()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthService())
            .environmentObject(UserProfile())
            .environmentObject(ScanHistoryStore())
            .environmentObject(FavoritesStore())
            .environmentObject(AmbientAudioService())
            .preferredColorScheme(.dark)
    }
}
