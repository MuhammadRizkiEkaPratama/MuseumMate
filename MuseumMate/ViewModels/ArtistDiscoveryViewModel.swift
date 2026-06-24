//
//  ArtistDiscoveryViewModel.swift
//  MuseumMate
//
//  Drives the Artist Discovery tab. Shows 40 artists from ArtistLibrary with
//  Wikipedia portraits; loads rich DeepSeek bios on demand. When the local
//  search returns no results, asks DeepSeek to identify the artist by name —
//  enabling discovery of regional artists like Raden Saleh or Affandi.
//

import SwiftUI

@MainActor
final class ArtistDiscoveryViewModel: ObservableObject {

    @Published var selectedArtist: Artist?
    @Published var selectedProfile: ArtistProfile?
    @Published var portraitURLs: [String: String] = [:]
    @Published var isLoadingPortrait: Set<String> = []
    @Published var isLoadingBio = false
    @Published var bioError: String?

    @Published var searchText = ""

    // DeepSeek search for unrecognised artists.
    @Published var deepSeekFoundArtist: Artist?
    @Published var isDeepSeekSearching = false

    // "Born on your birthday" feature.
    @Published var birthdayArtist: BirthdayArtist?
    @Published var birthdayPortraitURL: String?
    @Published var isLoadingBirthday = false
    private var didLoadBirthday = false

    private let imageService = ArtistImageService()
    private let infoService  = ArtistInfoService()

    private var allArtists: [Artist] { ArtistLibrary.all }

    // Debounce task for DeepSeek search.
    private var searchTask: Task<Void, Never>?

    /// Local artists filtered by search query.
    var artists: [Artist] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allArtists }
        return allArtists.filter {
            $0.name.lowercased().contains(query)
                || $0.movement.lowercased().contains(query)
                || $0.nationality.lowercased().contains(query)
        }
    }

    // MARK: - Search

    /// Call from the view's .onChange(of: searchText). Triggers DeepSeek when local
    /// results are empty after a 0.7 s debounce.
    func onSearchChanged(_ newText: String) {
        searchTask?.cancel()
        deepSeekFoundArtist = nil
        isDeepSeekSearching = false

        let trimmed = newText.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, let self else { return }
            // Only call DeepSeek when the local filter has nothing.
            guard self.artists.isEmpty else { return }
            await self.performDeepSeekSearch(query: trimmed)
        }
    }

    private func performDeepSeekSearch(query: String) async {
        guard AppConfig.hasValidAPIKey else { return }
        isDeepSeekSearching = true
        do {
            let found = try await infoService.searchArtist(query: query)
            deepSeekFoundArtist = found
            // Pre-fetch portrait in background.
            if let url = await imageService.fetchPortraitURL(for: found.name) {
                portraitURLs[found.name] = url
            }
        } catch {
            print("[ArtistSearch] DeepSeek search failed: \(error.localizedDescription)")
        }
        isDeepSeekSearching = false
    }

    // MARK: - Birthday artist

    func loadBirthdayArtist(month: Int, day: Int) async {
        guard !didLoadBirthday, AppConfig.hasValidAPIKey else { return }
        didLoadBirthday = true
        isLoadingBirthday = true
        do {
            let artist = try await infoService.fetchArtistBornOn(month: month, day: day)
            birthdayArtist = artist
            if let url = await imageService.fetchPortraitURL(for: artist.name) {
                birthdayPortraitURL = url
            }
        } catch {
            print("[Birthday] lookup failed: \(error.localizedDescription)")
            didLoadBirthday = false
        }
        isLoadingBirthday = false
    }

    func selectBirthdayArtist() {
        guard let b = birthdayArtist else { return }
        let artist = b.asArtist()
        if let url = birthdayPortraitURL { portraitURLs[artist.name] = url }
        selectArtist(artist)
    }

    // MARK: - Portraits

    func loadPortrait(for artist: Artist) async {
        let name = artist.name
        guard portraitURLs[name] == nil, !isLoadingPortrait.contains(name) else { return }
        isLoadingPortrait.insert(name)
        if let url = await imageService.fetchPortraitURL(for: name) {
            portraitURLs[name] = url
        }
        isLoadingPortrait.remove(name)
    }

    // MARK: - Biography

    func selectArtist(_ artist: Artist) {
        selectedArtist = artist
        selectedProfile = nil
        bioError = nil
        Task { await loadBio(for: artist) }
    }

    private func loadBio(for artist: Artist) async {
        isLoadingBio = true
        do {
            var profile = try await infoService.fetchArtistInfo(name: artist.name)
            if let url = portraitURLs[artist.name] {
                profile = ArtistProfile(
                    name: profile.name, nationality: profile.nationality,
                    born: profile.born, died: profile.died,
                    movement: profile.movement, bio: profile.bio,
                    famousWorks: profile.famousWorks, portraitURL: url,
                    accentColorHex: artist.accentColorHex
                )
            }
            selectedProfile = profile
        } catch {
            bioError = (error as? LocalizedError)?.errorDescription
                ?? "Could not load artist information."
        }
        isLoadingBio = false
    }
}
