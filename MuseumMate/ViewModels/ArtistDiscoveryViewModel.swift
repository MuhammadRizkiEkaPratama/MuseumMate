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

    private let imageService = ArtistImageService()
    private let infoService  = ArtistInfoService()

    var artists: [Artist] { ArtistLibrary.all }

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
