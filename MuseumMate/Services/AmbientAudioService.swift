//
//  AmbientAudioService.swift
//  MuseumMate
//
//  Global museum ambient player. Shuffles through ALL audio files found in
//  the bundle (classical_*.mp3, audio_*.mp3, museum_*.mp3, etc.) and also
//  supports per-artwork movement-specific tracks in ArtworkDetailView.
//
//  HOW TO ADD AUDIO FILES:
//  1. Download royalty-free classical tracks from musopen.org (see note below).
//  2. Name them: classical_01.mp3, classical_02.mp3, ... classical_N.mp3
//     OR movement-specific: audio_baroque.mp3, audio_impressionism.mp3, etc.
//  3. In Xcode: drag into MuseumMate/Resources/Audio/ → check "Add to target".
//  4. Build & run. The player discovers them automatically via Bundle scan.
//
//  RECOMMENDED FREE DOWNLOADS (musopen.org — public domain, no copyright):
//    - Debussy "Clair de Lune"      → classical_01.mp3
//    - Chopin Nocturne Op.9 No.2    → classical_02.mp3
//    - Bach "Air on G String"       → classical_03.mp3
//    - Beethoven "Moonlight Sonata" → classical_04.mp3
//    - Satie "Gymnopédie No.1"      → classical_05.mp3
//    - Ravel "Pavane"               → classical_06.mp3
//    - Mozart Piano Sonata K.331    → classical_07.mp3
//    - Schubert "Ave Maria"         → classical_08.mp3
//    - Vivaldi "Four Seasons Spring"→ classical_09.mp3
//    - Handel "Water Music Suite"   → classical_10.mp3
//  Add as many as you like — all are picked up automatically.
//

import Foundation
import AVFoundation
import MediaPlayer

@MainActor
final class AmbientAudioService: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentMovement: String = ""
    @Published var currentTrackName: String = ""
    @Published var currentTrackIndex: Int = 0
    @Published var trackCount: Int = 0

    // MARK: - Private

    private var player: AVAudioPlayer?
    private var trackList: [URL] = []        // bundle + user-imported tracks
    private var userTrackURLs: [URL] = []    // files copied to Documents by user
    private var isMuseumMode: Bool = false

    private let userTracksKey = "museummate_user_tracks"
    private let defaults = UserDefaults.standard

    // MARK: - Movement → filename map

    private let movementAudioMap: [String: String] = [
        "baroque":            "audio_baroque",
        "renaissance":        "audio_renaissance",
        "impressionism":      "audio_impressionism",
        "post-impressionism": "audio_impressionism",
        "romanticism":        "audio_romanticism",
        "realism":            "audio_ambient",
        "surrealism":         "audio_surrealism",
        "cubism":             "audio_modern",
        "abstract":           "audio_modern",
        "pop art":            "audio_popart",
        "expressionism":      "audio_expressionism",
        "art nouveau":        "audio_renaissance",
        "ukiyo":              "audio_eastern",
        "japanese":           "audio_eastern",
        "golden age":         "audio_baroque",
    ]

    // MARK: - Init

    override init() {
        super.init()
        loadUserTracks()
        buildTrackList()
    }

    // MARK: - User-added tracks (imported from Files / music library)

    /// Import an audio file from a URL (e.g. picked via UIDocumentPickerViewController).
    /// Copies the file to the app's Documents/UserMusic/ folder so it persists.
    func importTrack(from sourceURL: URL) {
        let musicDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UserMusic", isDirectory: true)
        try? FileManager.default.createDirectory(at: musicDir,
                                                  withIntermediateDirectories: true)
        let dest = musicDir.appendingPathComponent(sourceURL.lastPathComponent)
        if !FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.copyItem(at: sourceURL, to: dest)
        }
        if !userTrackURLs.contains(dest) {
            userTrackURLs.append(dest)
            saveUserTracks()
            buildTrackList()
        }
    }

    func removeUserTrack(at index: Int) {
        guard userTrackURLs.indices.contains(index) else { return }
        let url = userTrackURLs.remove(at: index)
        try? FileManager.default.removeItem(at: url)
        saveUserTracks()
        buildTrackList()
    }

    /// All user-imported track display names (for Settings list).
    var userTrackNames: [String] {
        userTrackURLs.map {
            $0.deletingPathExtension().lastPathComponent
        }
    }

    private func saveUserTracks() {
        let paths = userTrackURLs.map { $0.path }
        defaults.set(paths, forKey: userTracksKey)
    }

    private func loadUserTracks() {
        let paths = defaults.stringArray(forKey: userTracksKey) ?? []
        userTrackURLs = paths.compactMap { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: - Museum-wide ambient (shuffle all tracks)

    func startMuseumAmbient() {
        isMuseumMode = true
        if trackList.isEmpty { buildTrackList() }
        guard !trackList.isEmpty else { return }
        play(url: trackList[currentTrackIndex])
    }

    func pause() {
        player?.pause()
        isPlaying = false
        isPaused = true
    }

    func resume() {
        guard isPaused, let p = player else {
            if isMuseumMode { startMuseumAmbient() }
            return
        }
        p.play()
        isPlaying = true
        isPaused = false
    }

    func next() {
        guard !trackList.isEmpty else { return }
        currentTrackIndex = (currentTrackIndex + 1) % trackList.count
        play(url: trackList[currentTrackIndex])
        isPaused = false
    }

    func previous() {
        guard !trackList.isEmpty else { return }
        currentTrackIndex = (currentTrackIndex - 1 + trackList.count) % trackList.count
        play(url: trackList[currentTrackIndex])
        isPaused = false
    }

    // MARK: - Per-artwork movement playback (used in ArtworkDetailView)

    func play(forMovement movement: String) {
        guard !movement.isEmpty else { return }
        if isMuseumMode { return }   // museum mode takes priority
        if isPlaying && currentMovement == movement { return }

        stopPlayback()
        let fileName = resolve(movement: movement)
        guard let url = bundleURL(for: fileName) else { return }
        currentMovement = movement
        isMuseumMode = false
        play(url: url, looping: true)
    }

    func togglePlayback(forMovement movement: String) {
        if isMuseumMode { return }
        if isPlaying && currentMovement == movement {
            stopPlayback()
        } else {
            play(forMovement: movement)
        }
    }

    // MARK: - Stop

    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        isPaused = false
        currentMovement = ""
        currentTrackName = ""
        isMuseumMode = false
    }

    func stopMuseumAmbient() {
        stopPlayback()
    }

    // MARK: - Private helpers

    private func play(url: URL, looping: Bool = false) {
        do {
            try AVAudioSession.sharedInstance()
                .setCategory(.ambient, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.numberOfLoops = looping ? -1 : 0
            p.volume = 0.28
            p.play()
            player = p
            isPlaying = true
            // Display track name without prefix/extension
            currentTrackName = url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "classical ", with: "")
                .replacingOccurrences(of: "audio ", with: "")
                .capitalized
        } catch {
            // Audio file unreadable — silent fallback.
        }
    }

    private func buildTrackList() {
        // Bundle audio files (classical_*.mp3, audio_*.mp3, etc.)
        let extensions = ["mp3", "m4a", "aac"]
        var found: [URL] = []
        for ext in extensions {
            let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
            found.append(contentsOf: urls)
        }
        // Merge with user-imported files, shuffle entire list
        let all = (found + userTrackURLs).shuffled()
        trackList = all
        trackCount = all.count
    }

    private func resolve(movement: String) -> String {
        let lower = movement.lowercased()
        let sorted = movementAudioMap.keys.sorted { $0.count > $1.count }
        for key in sorted {
            if lower.contains(key) { return movementAudioMap[key]! }
        }
        return "audio_ambient"
    }

    private func bundleURL(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp3")
            ?? Bundle.main.url(forResource: name, withExtension: "m4a")
            ?? Bundle.main.url(forResource: name, withExtension: "aac")
    }
}

// MARK: - AVAudioPlayerDelegate (auto-advance in museum mode)

extension AmbientAudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        Task { @MainActor in
            if self.isMuseumMode {
                self.next()
            }
        }
    }
}
