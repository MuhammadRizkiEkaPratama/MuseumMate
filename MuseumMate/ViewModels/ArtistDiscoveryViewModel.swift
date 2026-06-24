//
//  ArtistDiscoveryViewModel.swift
//  MuseumMate
//
//  Drives the Artist Discovery tab. Shows the 12 known artists from
//  ArtistLibrary with their Wikipedia portraits; loads rich DeepSeek bios
//  on demand when a card is tapped.
//

import SwiftUI

@MainActor
final class ArtistDiscoveryViewModel: ObservableObject {

    @Published var selectedArtist: Artist?
    @Published var selectedProfile: ArtistProfile?
    @Published var portraitURLs: [String: String] = [:]   // name → URL string
    @Published var isLoadingPortrait: Set<String> = []
    @Published var isLoadingBio = false
    @Published var bioError: String?

    @Published var searchText = ""

    // "Born on your birthday" feature.
    @Published var birthdayArtist: BirthdayArtist?
    @Published var birthdayPortraitURL: String?
    @Published var isLoadingBirthday = false
    private var didLoadBirthday = false

    private let imageService = ArtistImageService()
    private let infoService  = ArtistInfoService()

    private var allArtists: [Artist] { ArtistLibrary.all }

    /// The 12 artists filtered by the search query (name, movement, nationality).
    var artists: [Artist] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allArtists }
        return allArtists.filter {
            $0.name.lowercased().contains(query)
                || $0.movement.lowercased().contains(query)
                || $0.nationality.lowercased().contains(query)
        }
    }

    // MARK: - Birthday artist

    func loadBirthdayArtist(month: Int, day: Int) async {
        guard !didLoadBirthday, AppConfig.hasValidAPIKey else { return }
        didLoadBirthday = true
        isLoadingBirthday = true
        do {
            let artist = try await infoService.fetchArtistBornOn(month: month, day: day)
            birthdayArtist = artist
            // Fetch a Wikipedia portrait for the birthday artist too.
            if let url = await imageService.fetchPortraitURL(for: artist.name) {
                birthdayPortraitURL = url
            }
        } catch {
            // Silent failure — the birthday card simply doesn't appear.
            print("[Birthday] lookup failed: \(error.localizedDescription)")
            didLoadBirthday = false   // allow a retry on next appearance
        }
        isLoadingBirthday = false
    }

    /// Opens the bio sheet for the birthday artist (not one of the fixed 12).
    func selectBirthdayArtist() {
        guard let b = birthdayArtist else { return }
        let artist = b.asArtist()
        if let url = birthdayPortraitURL { portraitURLs[artist.name] = url }
        selectArtist(artist)
    }

    func loadPortrait(for artist: Artist) async {
        let name = artist.name
        guard portraitURLs[name] == nil, !isLoadingPortrait.contains(name) else { return }
        isLoadingPortrait.insert(name)
        if let url = await imageService.fetchPortraitURL(for: name) {
            portraitURLs[name] = url
        }
        isLoadingPortrait.remove(name)
    }

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
            // Inject the Wikipedia portrait URL if we already have it.
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
