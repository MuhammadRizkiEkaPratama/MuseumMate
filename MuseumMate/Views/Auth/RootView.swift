//
//  RootView.swift
//  MuseumMate
//
//  The top-level gate. First launch shows onboarding; then sign-in;
//  then the main tab shell. Transitions cross-fade — never a hard cut.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var profile: UserProfile

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            content
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.35), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.35), value: profile.hasCompletedOnboarding)
    }

    @ViewBuilder
    private var content: some View {
        if !profile.hasCompletedOnboarding {
            OnboardingView()
        } else if !auth.isAuthenticated {
            AuthView()
        } else {
            ContentView()
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(AuthService())
            .environmentObject(UserProfile())
            .preferredColorScheme(.dark)
    }
}
