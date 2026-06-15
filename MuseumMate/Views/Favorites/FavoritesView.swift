//
//  FavoritesView.swift
//  MuseumMate
//
//  Saved works as a two-column gallery wall. Each cell is a full-bleed
//  thumbnail with a title overlay; tap to open the detail.
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if favoritesStore.favorites.isEmpty {
                    EmptyStateView(
                        symbol: "heart",
                        message: "Save the works that move you."
                    )
                } else {
                    grid
                }
            }
            .navigationTitle("Favorites")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var grid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(favoritesStore.favorites.enumerated()), id: \.element.id) { index, result in
                    NavigationLink {
                        ArtworkDetailView(result: result)
                    } label: {
                        FavoriteCell(result: result)
                    }
                    .buttonStyle(.pressable)
                    .fadeSlideIn(delay: Double(index) * 0.06)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Cell

private struct FavoriteCell: View {
    let result: ScanResult

    private var accent: Color { ArtStyleLibrary.accentColor(for: result.displayStyle) }

    var body: some View {
        ScanThumbnail(result: result, cornerRadius: 16)
            .aspectRatio(0.82, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
                titleOverlay
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var titleOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.displayStyle)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundStyle(accent)
            Text(result.displayTitle)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            LinearGradient(
                colors: [.clear, Color.appBackground.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView()
            .environmentObject(FavoritesStore())
            .preferredColorScheme(.dark)
    }
}
