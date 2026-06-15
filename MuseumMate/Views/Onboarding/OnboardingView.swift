//
//  OnboardingView.swift
//  MuseumMate
//
//  A three-screen welcome, shown once on first launch.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var profile: UserProfile
    @State private var page = 0

    private let lastPage = 2

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    pillarsPage.tag(1)
                    closingPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: page)

                dots
                    .padding(.bottom, 24)

                bottomControl
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Page 1 — welcome

    @ViewBuilder
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "building.columns")
                .font(.system(size: 76, weight: .ultraLight))
                .foregroundStyle(Color.appAccent)
                .fadeSlideIn()

            VStack(spacing: 16) {
                Text("Welcome to\nMuseumMate")
                    .font(.system(.largeTitle, design: .serif).weight(.light))
                    .foregroundStyle(Color.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fadeSlideIn(delay: 0.08)

                Text("Point your camera at any artwork and uncover the story behind it.")
                    .font(.body)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 36)
                    .fadeSlideIn(delay: 0.16)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Page 2 — the three pillars

    @ViewBuilder
    private var pillarsPage: some View {
        VStack(alignment: .leading, spacing: 32) {
            Spacer()
            Text("How it works")
                .font(.system(.title, design: .serif).weight(.light))
                .foregroundStyle(Color.appTextPrimary)
                .fadeSlideIn()

            VStack(spacing: 24) {
                pillarRow(
                    icon: "viewfinder",
                    title: "Scan",
                    description: "Capture or import a photo of any painting.",
                    delay: 0.10
                )
                pillarRow(
                    icon: "sparkles",
                    title: "Dual AI",
                    description: "Offline style detection meets cloud-powered identification.",
                    delay: 0.18
                )
                pillarRow(
                    icon: "heart.text.square",
                    title: "Collection",
                    description: "Save the works that move you and revisit them anytime.",
                    delay: 0.26
                )
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private func pillarRow(icon: String, title: String, description: String, delay: Double) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.appAccent)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .fadeSlideIn(delay: delay)
    }

    // MARK: - Page 3 — closing

    @ViewBuilder
    private var closingPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(Color.appAccent)
                .fadeSlideIn()

            VStack(spacing: 16) {
                Text("Your gallery\nawaits")
                    .font(.system(.largeTitle, design: .serif).weight(.light))
                    .foregroundStyle(Color.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fadeSlideIn(delay: 0.08)

                Text("Step up to any artwork and let its story unfold.")
                    .font(.body)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 36)
                    .fadeSlideIn(delay: 0.16)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Controls

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0...lastPage, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.appAccent : Color.appTextMuted)
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .animation(.museumSpring, value: page)
            }
        }
    }

    @ViewBuilder
    private var bottomControl: some View {
        Button {
            Haptics.tap()
            if page < lastPage {
                withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
            } else {
                Haptics.success()
                withAnimation(.easeInOut(duration: 0.35)) {
                    profile.hasCompletedOnboarding = true
                }
            }
        } label: {
            Text(page < lastPage ? "Continue" : "Start Exploring")
                .font(.headline)
                .foregroundStyle(Color.appBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appAccent)
                )
        }
        .buttonStyle(.pressable)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(UserProfile())
            .preferredColorScheme(.dark)
    }
}
