//
//  ProfileView.swift
//  MuseumMate
//
//  Account, collection stats, and app info. Sign-out is stubbed locally;
//  Firebase account management arrives in Phase 7.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var profile: UserProfile
    @EnvironmentObject private var historyStore: ScanHistoryStore
    @EnvironmentObject private var favoritesStore: FavoritesStore

    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        headerCard.fadeSlideIn()
                        statsRow.fadeSlideIn(delay: 0.06)
                        accountSection.fadeSlideIn(delay: 0.12)
                        appSection.fadeSlideIn(delay: 0.18)
                        dangerSection.fadeSlideIn(delay: 0.24)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Profile")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Haptics.impact(.medium)
                    auth.signOut()
                    profile.reset()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can sign back in anytime. Your scans stay on this device.")
            }
        }
    }

    // MARK: - Header

    private var displayName: String {
        auth.currentUserName.isEmpty ? "Art Lover" : auth.currentUserName
    }

    private var initial: String {
        let source = auth.currentUserName.isEmpty ? auth.currentUserEmail : auth.currentUserName
        return source.isEmpty ? "M" : String(source.prefix(1)).uppercased()
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.appSurfaceUp)
                    .frame(width: 88, height: 88)
                Circle()
                    .strokeBorder(Color.appAccent.opacity(0.4), lineWidth: 1)
                    .frame(width: 88, height: 88)
                Text(initial)
                    .font(.system(size: 38, design: .serif))
                    .foregroundStyle(Color.appAccent)
            }

            Text(displayName)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(Color.appTextPrimary)

            if !auth.currentUserEmail.isEmpty {
                Text(auth.currentUserEmail)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell(value: historyStore.scans.count, label: "Scans")
            statCell(value: favoritesStore.count, label: "Favorites")
            statCell(value: historyStore.uniqueStyleCount, label: "Styles")
        }
    }

    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(.title, design: .serif))
                .foregroundStyle(Color.appAccent)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.appTextMuted)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 16)
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account").sectionLabel()
            VStack(spacing: 0) {
                infoRow(icon: "person", title: "Name", value: displayName)
                rowDivider
                infoRow(icon: "envelope", title: "Email", value: auth.currentUserEmail.isEmpty ? "—" : auth.currentUserEmail)
                rowDivider
                // TODO: Firebase — wire real account management in Phase 7.
                infoRow(icon: "gearshape", title: "Manage Account", value: "Soon")
            }
            .card(padding: 16)
        }
    }

    // MARK: - App

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App").sectionLabel()
            VStack(spacing: 0) {
                infoRow(icon: "info.circle", title: "Version", value: appVersion)
                rowDivider
                infoRow(icon: "hand.raised", title: "Privacy", value: "On-device")
                rowDivider
                aboutRow
            }
            .card(padding: 16)
        }
    }

    private var aboutRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "building.columns")
                .font(.subheadline)
                .foregroundStyle(Color.appAccent)
                .frame(width: 22)
            Text("MuseumMate brings a museum guide to your pocket — offline style detection paired with cloud identification.")
                .font(.footnote)
                .foregroundStyle(Color.appTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Danger zone

    private var dangerSection: some View {
        Button {
            Haptics.tap()
            showSignOutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out").font(.headline)
                Spacer()
            }
            .foregroundStyle(Color.appDanger)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.appDanger.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Building blocks

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.appAccent)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.appTextMuted)
                .lineLimit(1)
        }
        .padding(.vertical, 12)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthService())
            .environmentObject(UserProfile())
            .environmentObject(ScanHistoryStore())
            .environmentObject(FavoritesStore())
            .preferredColorScheme(.dark)
    }
}
