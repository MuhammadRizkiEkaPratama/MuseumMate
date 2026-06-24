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
    @EnvironmentObject private var profile: UserProfile

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
                        searchBar
                            .fadeSlideIn(delay: 0.04)
                        birthdaySection
                            .fadeSlideIn(delay: 0.08)
                        artistGrid
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
            .task {
                if let bday = profile.birthdayMonthDay {
                    await viewModel.loadBirthdayArtist(month: bday.month, day: bday.day)
                }
            }
            .onChange(of: viewModel.searchText) { newText in
                viewModel.onSearchChanged(newText)
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

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.appTextMuted)
            TextField("", text: $viewModel.searchText,
                      prompt: Text("Search artist, movement, country").foregroundColor(.appTextMuted))
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
                .tint(Color.appAccent)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.appTextMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurface))
        .padding(.horizontal, 24)
    }

    // MARK: - Birthday section

    @ViewBuilder
    private var birthdaySection: some View {
        if profile.birthdayMonthDay != nil && viewModel.searchText.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Born On Your Birthday").sectionLabel()
                if viewModel.isLoadingBirthday && viewModel.birthdayArtist == nil {
                    HStack(spacing: 14) {
                        SkeletonView(cornerRadius: 12).frame(width: 64, height: 64)
                        SkeletonLines(count: 2)
                    }
                    .card(padding: 14)
                } else if let b = viewModel.birthdayArtist {
                    BirthdayArtistCard(artist: b, portraitURL: viewModel.birthdayPortraitURL) {
                        Haptics.tap()
                        viewModel.selectBirthdayArtist()
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private var artistGrid: some View {
        if viewModel.artists.isEmpty {
            VStack(spacing: 20) {
                EmptyStateView(symbol: "magnifyingglass",
                               message: "No artists match \u{201C}\(viewModel.searchText)\u{201D}.")
                    .padding(.top, 8)

                // DeepSeek AI search result
                if viewModel.isDeepSeekSearching {
                    deepSeekSearchingCard
                } else if let found = viewModel.deepSeekFoundArtist {
                    deepSeekResultCard(found)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        } else {
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
    }

    // MARK: - DeepSeek search cards

    private var deepSeekSearchingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(Color.appAccent)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("Searching with AI...")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                Text("Looking up this artist via DeepSeek")
                    .font(.caption)
                    .foregroundStyle(Color.appTextMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.25), lineWidth: 0.5)
        )
    }

    private func deepSeekResultCard(_ artist: Artist) -> some View {
        Button {
            Haptics.tap()
            viewModel.selectArtist(artist)
        } label: {
            HStack(spacing: 14) {
                // Portrait or initial placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: artist.accentColorHex).opacity(0.15))
                    if let url = viewModel.portraitURLs[artist.name], let parsed = URL(string: url) {
                        AsyncImage(url: parsed) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                                    .frame(width: 56, height: 56).clipped()
                            } else {
                                Text(String(artist.name.prefix(1)))
                                    .font(.system(size: 26, design: .serif).weight(.light))
                                    .foregroundStyle(Color(hex: artist.accentColorHex))
                            }
                        }
                    } else {
                        Text(String(artist.name.prefix(1)))
                            .font(.system(size: 26, design: .serif).weight(.light))
                            .foregroundStyle(Color(hex: artist.accentColorHex))
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(Color.appAccent)
                        Text("Found via AI")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                    Text(artist.name)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                    Text("\(artist.nationality) · \(artist.movement)")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                    Text("\(artist.born) – \(artist.died)")
                        .font(.caption2)
                        .foregroundStyle(Color.appTextMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.appAccent)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.appAccent.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Birthday artist card

struct BirthdayArtistCard: View {
    let artist: BirthdayArtist
    let portraitURL: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                portrait
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.name)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                    if !artist.note.isEmpty {
                        Text(artist.note)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("\(artist.movement) · \(artist.born)")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.appAccent)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appAccent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.appAccent.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.pressable)
    }

    @ViewBuilder
    private var portrait: some View {
        if let urlString = portraitURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    // Explicit frame + clipped inside AsyncImage prevents overflow.
                    img.resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64, alignment: .top)
                        .clipped()
                case .empty: SkeletonView(cornerRadius: 0)
                default: placeholder
                }
            }
            .frame(width: 64, height: 64)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Color.appAccent.opacity(0.15)
            .overlay(
                Image(systemName: "gift")
                    .font(.title3)
                    .foregroundStyle(Color.appAccent)
            )
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
                    VStack(alignment: .leading, spacing: 0) {
                        heroSection
                            .fadeSlideIn()

                        // Artist identity — placed BELOW image with solid
                        // appBackground backing so it never overlaps the photo.
                        artistIdentity
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                            .fadeSlideIn(delay: 0.04)

                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 1)
                            .padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 20) {
                            if isLoading {
                                loadingSection
                                    .fadeSlideIn(delay: 0.08)
                            } else if let error {
                                errorSection(error)
                                    .fadeSlideIn(delay: 0.08)
                            } else if let profile {
                                bioContent(profile)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
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

    // Hero image only — no text inside ZStack to prevent overlap.
    @ViewBuilder
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            portraitHero
            // Gradient fades image into appBackground so the identity
            // section below reads cleanly against a solid background.
            LinearGradient(
                colors: [.clear, Color.appBackground],
                startPoint: .init(x: 0.5, y: 0.55),
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
        .frame(height: 260)
        .clipped()  // prevent scaledToFill image from bleeding outside frame
    }

    // Artist name / nationality / dates — own layout row, never overlaps image.
    private var artistIdentity: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(artist.name)
                .font(.system(.title, design: .serif).weight(.regular))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(artist.nationality) · \(artist.movement)")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
            Text("\(artist.born) – \(artist.died)")
                .font(.caption)
                .foregroundStyle(Color.appTextMuted)
        }
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
