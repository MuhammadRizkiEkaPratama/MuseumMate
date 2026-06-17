//
//  CollectionView.swift
//  MuseumMate
//
//  "Art Pieces" — a 2-column gallery grid of all scanned artworks.
//  Filter by All / Favorites and search by title or artist.
//

import SwiftUI

struct CollectionView: View {
    @Binding var selectedTab: AppTab

    @EnvironmentObject private var historyStore: ScanHistoryStore
    @EnvironmentObject private var favoritesStore: FavoritesStore

    enum Mode: CaseIterable {
        case all, favorites
        var title: String { self == .all ? "All" : "Favorites" }
    }

    @State private var mode: Mode = .all
    @State private var searchText = ""
    @State private var selectedStyle: String?
    @State private var pendingDelete: ScanResult?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Stacked serif header
                    pageHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Stats + mode switcher
                    statRow
                        .padding(.horizontal, 24)
                        .padding(.bottom, 14)

                    modeSwitcher
                        .padding(.bottom, 12)

                    // Search + filter chips
                    searchBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)

                    styleChips
                        .padding(.bottom, 12)

                    // Grid content
                    gridContent
                }
            }
            .navigationBarHidden(true)
            .confirmationDialog("Delete this scan?", isPresented: deleteBinding, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let item = pendingDelete {
                        Haptics.impact(.medium)
                        historyStore.delete(item)
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This removes the scan and its saved image.")
            }
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Art")
                    .font(.system(size: 36, design: .serif).weight(.light))
                    .foregroundStyle(Color.appTextPrimary)
                Text("Pieces")
                    .font(.system(size: 36, design: .serif).weight(.regular))
                    .foregroundStyle(Color.appAccent)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(historyStore.scans.count)")
                    .font(.system(.title, design: .serif))
                    .foregroundStyle(Color.appAccent)
                Text("scanned")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextMuted)
            }
        }
    }

    // MARK: - Stat row

    private var statRow: some View {
        HStack(spacing: 12) {
            statPill(value: historyStore.scans.count, label: "Total")
            statPill(value: favoritesStore.count, label: "Saved")
            statPill(value: historyStore.uniqueStyleCount, label: "Artists")
        }
    }

    private func statPill(value: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.appAccent)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.appTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Mode switcher

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.self) { option in
                Button {
                    withAnimation(.museumSpring) { mode = option }
                    Haptics.tap()
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(mode == option ? Color.appTextPrimary : Color.appTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(alignment: .bottom) {
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: proxy.size.width / 2, height: 2)
                    .offset(x: mode == .all ? 0 : proxy.size.width / 2)
                    .animation(.museumSpring, value: mode)
            }
            .frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.appTextMuted)
                .font(.subheadline)
            TextField("", text: $searchText,
                      prompt: Text("Search title or artist").foregroundColor(.appTextMuted))
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
                .tint(Color.appAccent)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appTextMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appSurface)
        )
    }

    // MARK: - Style chips

    @ViewBuilder
    private var styleChips: some View {
        let styles = availableStyles
        if !styles.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "All", active: selectedStyle == nil) { selectedStyle = nil }
                    ForEach(styles, id: \.self) { style in
                        chip(title: style, active: selectedStyle == style) {
                            selectedStyle = style
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.museumSpring) { action() }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? Color.appBackground : Color.appTextSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(active ? Color.appAccent : Color.appSurface))
                .overlay(Capsule().strokeBorder(Color.white.opacity(active ? 0 : 0.06), lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Grid content

    @ViewBuilder
    private var gridContent: some View {
        let results = filteredResults
        if results.isEmpty {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        NavigationLink {
                            ArtworkDetailView(result: result)
                        } label: {
                            ArtPieceCard(result: result)
                                .fadeSlideIn(delay: Double(min(index, 8)) * 0.04)
                                .contextMenu {
                                    Button {
                                        Haptics.impact(.light)
                                        historyStore.toggleFavorite(result)
                                    } label: {
                                        Label(
                                            result.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                            systemImage: result.isFavorite ? "heart.slash" : "heart"
                                        )
                                    }
                                    Button(role: .destructive) {
                                        pendingDelete = result
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            EmptyStateView(symbol: "magnifyingglass",
                           message: "No artworks match \"\(searchText)\".")
        } else if mode == .favorites {
            EmptyStateView(symbol: "heart",
                           message: "Save artworks that move you.")
        } else {
            EmptyStateView(
                symbol: "photo.artframe",
                message: "Your scanned artworks will appear here.",
                actionTitle: "Start Scanning",
                action: { selectedTab = .scan }
            )
        }
    }

    // MARK: - Filtering

    private var baseResults: [ScanResult] {
        mode == .all ? historyStore.scans : favoritesStore.favorites
    }

    private var availableStyles: [String] {
        let styles = historyStore.scans
            .map { $0.displayStyle }
            .filter { !$0.isEmpty && $0.lowercased() != "unknown" }
        return Array(Set(styles)).sorted()
    }

    private var filteredResults: [ScanResult] {
        var results = baseResults
        if let selectedStyle {
            results = results.filter { $0.displayStyle == selectedStyle }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            results = results.filter { result in
                result.displayTitle.lowercased().contains(query)
                    || (result.artwork?.artist.lowercased().contains(query) ?? false)
                    || result.localArtist.lowercased().contains(query)
            }
        }
        return results
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
}

// MARK: - Art Piece Card (gallery arch card)

private struct ArtPieceCard: View {
    let result: ScanResult
    private var accent: Color { ArtistLibrary.accentColor(for: result.localArtist) }

    var body: some View {
        VStack(spacing: 0) {
            // Artwork image — fills top 65% of card
            ScanThumbnail(result: result, cornerRadius: 0)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()

            // Info strip
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayTitle)
                    .font(.system(.caption, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let artist = result.artwork?.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.caption2)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 0) {
                    Text(result.displayStyle)
                        .font(.system(size: 9, weight: .semibold))
                        .textCase(.uppercase)
                        .kerning(0.5)
                        .foregroundStyle(accent)
                    Spacer(minLength: 4)
                    if result.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }
}

struct CollectionView_Previews: PreviewProvider {
    static var previews: some View {
        CollectionView(selectedTab: .constant(.collection))
            .environmentObject(ScanHistoryStore())
            .environmentObject(FavoritesStore())
            .preferredColorScheme(.dark)
    }
}
