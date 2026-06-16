//
//  CollectionView.swift
//  MuseumMate
//
//  History + Favorites merged into one searchable, filterable collection.
//

import SwiftUI

struct CollectionView: View {
    @Binding var selectedTab: AppTab

    @EnvironmentObject private var historyStore: ScanHistoryStore
    @EnvironmentObject private var favoritesStore: FavoritesStore

    enum Mode: CaseIterable { case all, favorites
        var title: String { self == .all ? "All Scans" : "Favorites" }
    }

    @State private var mode: Mode = .all
    @State private var searchText = ""
    @State private var selectedStyle: String?
    @State private var pendingDelete: ScanResult?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 16) {
                    statPills
                    modeSwitcher
                    searchBar
                    styleChips
                    content
                }
                .padding(.top, 8)
            }
            .navigationTitle("My Collection")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog("Delete this scan?", isPresented: deleteBinding, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let pendingDelete {
                        Haptics.impact(.medium)
                        historyStore.delete(pendingDelete)
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This removes the scan and its saved image.")
            }
        }
    }

    // MARK: - Stat pills

    private var statPills: some View {
        HStack(spacing: 12) {
            statPill(value: historyStore.scans.count, label: "Artworks Scanned")
            statPill(value: favoritesStore.count, label: "Favorites")
        }
        .padding(.horizontal, 24)
    }

    private func statPill(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.title2, design: .serif))
                .foregroundStyle(Color.appAccent)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.appTextMuted)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 14)
    }

    // MARK: - Mode switcher (sliding gold underline)

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
            TextField("", text: $searchText, prompt: Text("Search title, artist, style").foregroundColor(.appTextMuted))
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
                .tint(Color.appAccent)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
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

    // MARK: - Style chips

    @ViewBuilder
    private var styleChips: some View {
        let styles = availableStyles
        if !styles.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "All", active: selectedStyle == nil) { selectedStyle = nil }
                    ForEach(styles, id: \.self) { style in
                        chip(title: style, active: selectedStyle == style) { selectedStyle = style }
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
                .background(
                    Capsule().fill(active ? Color.appAccent : Color.appSurface)
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(active ? 0 : 0.06), lineWidth: 0.5)
                )
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let results = filteredResults
        if results.isEmpty {
            emptyState
        } else {
            List {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    row(for: result)
                        .fadeSlideIn(delay: Double(min(index, 8)) * 0.04)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
    }

    private func row(for result: ScanResult) -> some View {
        ZStack {
            NavigationLink {
                ArtworkDetailView(result: result)
            } label: { EmptyView() }
            .opacity(0)

            CollectionRow(result: result)
        }
        .listRowBackground(Color.appBackground)
        .listRowSeparatorTint(Color.white.opacity(0.06))
        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { pendingDelete = result } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Haptics.impact(.light)
                historyStore.toggleFavorite(result)
            } label: {
                Label("Favorite", systemImage: result.isFavorite ? "heart.slash" : "heart")
            }
            .tint(Color.appAccent)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            EmptyStateView(symbol: "magnifyingglass", message: "No artworks match “\(searchText)”.")
        } else if mode == .favorites {
            EmptyStateView(symbol: "heart", message: "Save artworks that move you.")
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

// MARK: - Row

private struct CollectionRow: View {
    let result: ScanResult
    private var accent: Color { ArtistLibrary.accentColor(for: result.displayStyle) }

    var body: some View {
        HStack(spacing: 14) {
            ScanThumbnail(result: result, cornerRadius: 10)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayTitle)
                    .font(.system(.subheadline, design: .serif).weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)

                if let artist = result.artwork?.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(result.displayStyle)
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.6)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent.opacity(0.16)))
                    Text(result.formattedDate)
                        .font(.caption2)
                        .foregroundStyle(Color.appTextMuted)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                if result.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(Color.appAccent)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.appTextMuted)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
