//
//  ArtistDiscoveryView.swift
//  MuseumMate
//
//  Tab 4 — Artist Discovery. Displays the 12 artists in the Core ML library
//  as portrait cards. Tapping a card loads a full DeepSeek biography sheet.
//

import SwiftUI

struct ArtistDiscoveryView: View {

    @StateObject private var viewModel = ArtistDiscoveryViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                            .fadeSlideIn()

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(viewModel.artists.enumerated()), id: \.element.id) { index, artist in
                                ArtistCard(
                                    artist: artist,
                                    portraitURL: viewModel.portraitURLs[artist.name]
                                )
                                .fadeSlideIn(delay: Double(min(index, 8)) * 0.05)
                                .onTapGesture {
                                    Haptics.tap()
                                    viewModel.selectArtist(artist)
                                }
                                .task { await viewModel.loadPortrait(for: artist) }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Artists")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $viewModel.selectedArtist) { artist in
                ArtistBioSheet(
                    artist: artist,
                    portraitURL: viewModel.portraitURLs[artist.name],
                    profile: viewModel.selectedProfile,
                    isLoading: viewModel.isLoadingBio,
                    error: viewModel.bioError
                )
                .onDisappear { viewModel.selectedProfile = nil }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Artist\nDiscovery")
                .font(.system(.largeTitle, design: .serif).weight(.light))
                .foregroundStyle(Color.appTextPrimary)
                .lineSpacing(2)
            Text("12 masters recognized by MuseumMate's AI")
                .font(.subheadline)
                .foregroundStyle(Color.appTextMuted)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Artist card

struct ArtistCard: View {
    let artist: Artist
    let portraitURL: String?

    var body: some View {
        VStack(spacing: 0) {
            portraitArea
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                Text(artist.movement)
                    .font(.caption)
                    .foregroundStyle(Color(hex: artist.accentColorHex))
                    .lineLimit(1)
                Text("\(artist.born) – \(artist.died)")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
        .buttonStyle(.pressable)
    }

    @ViewBuilder
    private var portraitArea: some View {
        if let urlString = portraitURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .empty:
                    SkeletonView(cornerRadius: 0)
                default:
                    artistInitialPlaceholder
                }
            }
        } else {
            artistInitialPlaceholder
        }
    }

    private var artistInitialPlaceholder: some View {
        Color(hex: artist.accentColorHex).opacity(0.15)
            .overlay(
                Text(String(artist.name.prefix(1)))
                    .font(.system(size: 52, design: .serif).weight(.light))
                    .foregroundStyle(Color(hex: artist.accentColorHex).opacity(0.8))
            )
    }
}

// MARK: - Bio sheet

struct ArtistBioSheet: View {
    let artist: Artist
    let portraitURL: String?
    let profile: ArtistProfile?
    let isLoading: Bool
    let error: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        heroSection
                            .fadeSlideIn()

                        VStack(alignment: .leading, spacing: 20) {
                            if isLoading {
                                loadingSection
                                    .fadeSlideIn(delay: 0.06)
                            } else if let error {
                                errorSection(error)
                                    .fadeSlideIn(delay: 0.06)
                            } else if let profile {
                                bioContent(profile)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle(artist.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            portraitHero
            LinearGradient(
                colors: [.clear, Color.appBackground.opacity(0.95)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.system(.largeTitle, design: .serif).weight(.regular))
                    .foregroundStyle(Color.appTextPrimary)
                Text("\(artist.nationality) · \(artist.movement)")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                Text("\(artist.born) – \(artist.died)")
                    .font(.caption)
                    .foregroundStyle(Color.appTextMuted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(height: 280)
    }

    @ViewBuilder
    private var portraitHero: some View {
        if let urlString = portraitURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .empty:
                    SkeletonView(cornerRadius: 0)
                default:
                    Color(hex: artist.accentColorHex).opacity(0.2)
                }
            }
        } else {
            Color(hex: artist.accentColorHex).opacity(0.2)
                .overlay(
                    Text(String(artist.name.prefix(1)))
                        .font(.system(size: 80, design: .serif).weight(.ultraLight))
                        .foregroundStyle(Color(hex: artist.accentColorHex).opacity(0.5))
                )
        }
    }

    private var loadingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Biography").sectionLabel()
            SkeletonLines(count: 4)
            SkeletonLines(count: 3)
        }
    }

    private func errorSection(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(Color.appTextMuted)
            .card(padding: 16)
    }

    @ViewBuilder
    private func bioContent(_ p: ArtistProfile) -> some View {
        // Biography
        VStack(alignment: .leading, spacing: 12) {
            Text("Biography").sectionLabel()
            Text(p.bio)
                .font(.system(size: 15))
                .foregroundStyle(Color.appTextPrimary.opacity(0.9))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fadeSlideIn(delay: 0.06)

        // Famous works
        if !p.famousWorks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Notable Works").sectionLabel()
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(p.famousWorks.enumerated()), id: \.offset) { _, work in
                        HStack(alignment: .top, spacing: 10) {
                            Text("—").foregroundStyle(Color.appAccent)
                            Text(work)
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 16)
            }
            .fadeSlideIn(delay: 0.12)
        }
    }
}
