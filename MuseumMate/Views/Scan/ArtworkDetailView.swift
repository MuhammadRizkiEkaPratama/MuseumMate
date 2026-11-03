//
//  ArtworkDetailView.swift
//  MuseumMate
//
//  Premium catalog detail: tall hero with glass action buttons, artist portrait
//  overlay, metadata column, expandable history, fun facts with audio playback,
//  ambient music per art movement, love poems, and artist story.
//

import SwiftUI
import AVFoundation

// MARK: - Fun fact speaker (AVSpeechSynthesizer wrapper)

private final class FactSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var speakingIndex: Int? = nil
    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, index: Int) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        speakingIndex = index
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        utt.rate = 0.48
        utt.pitchMultiplier = 1.05
        synth.speak(utt)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        speakingIndex = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        speakingIndex = nil
    }
}

// MARK: - Main view

struct ArtworkDetailView: View {
    let result: ScanResult

    @EnvironmentObject private var historyStore: ScanHistoryStore
    @EnvironmentObject private var ambientAudio: AmbientAudioService
    @StateObject private var speaker = FactSpeaker()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var image: UIImage?
    @State private var artistPortraitURL: String?
    @State private var confidenceFill: Double = 0
    @State private var heartScale: CGFloat = 1
    @State private var historyExpanded = false

    private var artwork: Artwork? { result.artwork }
    private var detectedArtistInfo: Artist? { ArtistLibrary.artist(fromLabel: result.localArtist) }
    private var accent: Color { ArtistLibrary.accentColor(for: result.localArtist) }
    private var confidence: Double { artwork?.confidence ?? result.localConfidence }

    private var isFavorite: Bool {
        historyStore.scans.first { $0.id == result.id }?.isFavorite ?? result.isFavorite
    }

    // The movement used for ambient audio lookup
    private var artMovement: String {
        artwork?.style.isEmpty == false ? artwork!.style :
        (detectedArtistInfo?.movement ?? result.localArtist)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero: no entrance animation — it anchors the page visually
                heroSection

                VStack(alignment: .leading, spacing: 26) {
                    detailSectionsTop
                    detailSectionsBottom
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 40)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if image == nil {
                image = ImageStore.loadImage(named: result.imageFileName)
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) {
                confidenceFill = confidence
            }
            if let artistName = artwork?.artist ?? detectedArtistInfo?.name {
                artistPortraitURL = await ArtistImageService().fetchPortraitURL(for: artistName)
            }
        }
        .onDisappear {
            speaker.stop()
            ambientAudio.stopPlayback()
        }
    }

    // MARK: - Body section splits (ViewBuilder 10-child limit)

    @ViewBuilder
    private var detailSectionsTop: some View {
        identityCard
            .fadeSlideIn(delay: 0.04)
        metadataGrid
            .fadeSlideIn(delay: 0.08)
        confidenceSection
            .fadeSlideIn(delay: 0.12)
        descriptionSection
            .fadeSlideIn(delay: 0.16)
        shortHistorySection
            .fadeSlideIn(delay: 0.20)
        creationStorySection
            .fadeSlideIn(delay: 0.24)
    }

    @ViewBuilder
    private var detailSectionsBottom: some View {
        quoteSection
            .fadeSlideIn(delay: 0.28)
        funFactsCard
            .fadeSlideIn(delay: 0.32)
        lovePoemsSection
            .fadeSlideIn(delay: 0.36)
        romanticLineSection
            .fadeSlideIn(delay: 0.40)
        artistStorySection
            .fadeSlideIn(delay: 0.44)
        actionBar
            .fadeSlideIn(delay: 0.48)
    }

    // MARK: - Hero (55 % of screen height, clipped to its own frame)

    @ViewBuilder
    private var heroSection: some View {
        let heroHeight = UIScreen.main.bounds.height * 0.55

        ZStack(alignment: .bottom) {
            artworkHeroImage
                .frame(height: heroHeight)
                .frame(maxWidth: .infinity)
                .clipped()

            // Bottom vignette
            LinearGradient(
                colors: [.clear, Color.appBackground.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: heroHeight * 0.42)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            // Glass action buttons — top-right of the hero bottom area
            HStack {
                Spacer()
                HStack(spacing: 10) {
                    glassButton(symbol: isFavorite ? "heart.fill" : "heart",
                                tint: isFavorite ? Color.appAccent : .white) {
                        toggleFavorite()
                    }
                    // Ambient music toggle
                    glassButton(
                        symbol: ambientAudio.isPlaying ? "music.note.list" : "music.note",
                        tint: ambientAudio.isPlaying ? Color.appAccent : .white
                    ) {
                        ambientAudio.togglePlayback(forMovement: artMovement)
                        Haptics.tap()
                    }
                    glassButton(symbol: "square.and.arrow.up", tint: .white) {}
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .frame(height: heroHeight)
        .clipped()
        // ShareLink hidden behind the share glass button area
        .overlay(alignment: .bottomTrailing) {
            ShareLink(item: shareText) {
                Color.clear.frame(width: 44, height: 44)
            }
            .frame(width: 44, height: 44)
            .padding(.trailing, 66)  // sit behind the rightmost glass button
            .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private var artworkHeroImage: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color.appSurface
                .overlay(
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundStyle(Color.appTextMuted)
                )
        }
    }

    private var artistPortraitInset: some View {
        Group {
            if let urlString = artistPortraitURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        portraitPlaceholder
                    }
                }
            } else {
                portraitPlaceholder
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.appBackground, lineWidth: 2))
        .overlay(Circle().strokeBorder(accent.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
    }

    private var portraitPlaceholder: some View {
        Circle().fill(accent.opacity(0.2))
            .overlay(
                Text(String((detectedArtistInfo?.name ?? result.localArtist).prefix(1)))
                    .font(.system(size: 20, design: .serif))
                    .foregroundStyle(accent)
            )
    }

    private func glassButton(symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.pressable)
        .scaleEffect(symbol.contains("heart") ? heartScale : 1)
    }

    // MARK: - Identity card

    @ViewBuilder
    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Portrait + detected artist badge inline — avoids hero z-order overlap bug
            HStack(alignment: .center, spacing: 12) {
                artistPortraitInset

                VStack(alignment: .leading, spacing: 3) {
                    Text("Detected Artist").sectionLabel()
                    Text(detectedArtistInfo?.name ?? result.localArtist)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                    if let info = detectedArtistInfo {
                        Text("\(info.nationality) · \(info.movement)")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                        Text("\(info.born)–\(info.died)")
                            .font(.caption2)
                            .foregroundStyle(Color.appTextMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.12))
            )

            Text(result.displayTitle)
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(accent)
                .frame(width: 40, height: 2)

            if let artist = artwork?.artist, !artist.isEmpty {
                Text(artist)
                    .font(.title3.weight(.light))
                    .foregroundStyle(Color.appTextSecondary)
            }

            if let location = artwork?.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Metadata grid

    @ViewBuilder
    private var metadataGrid: some View {
        if let artwork, !artwork.year.isEmpty || !artwork.medium.isEmpty {
            let items: [(String, String, String)] = [
                ("calendar",          "Year",       artwork.year),
                ("paintbrush",        "Medium",     artwork.medium.isEmpty ? artwork.artStyle : artwork.medium),
                ("tag",               "Style",      artwork.style.isEmpty  ? artwork.artStyle : artwork.style),
                ("building.columns",  "Collection", artwork.exhibitionSince.isEmpty ? "" : "Since \(artwork.exhibitionSince)")
            ].filter { !$2.isEmpty }

            if !items.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(items, id: \.1) { icon, label, value in
                        metaCell(icon: icon, label: label, value: value)
                    }
                }
            }
        }
    }

    private func metaCell(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).sectionLabel().font(.system(size: 9, weight: .semibold))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5))
    }

    // MARK: - Confidence bar

    @ViewBuilder
    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Confidence").sectionLabel()
                Spacer()
                Text("\(Int(confidence * 100))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.appSurfaceUp)
                    Capsule()
                        .fill(accent)
                        .frame(width: proxy.size.width * confidenceFill)
                }
            }
            .frame(height: 6)
            .accessibilityElement()
            .accessibilityLabel("Confidence")
            .accessibilityValue("\(Int(confidence * 100)) percent")
        }
    }

    // MARK: - Description + "Listen" button (Opsi 6)

    @ViewBuilder
    private var descriptionSection: some View {
        if let description = artwork?.description, !description.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("About").sectionLabel()
                    Spacer()
                    listenButton(text: description, index: -1)
                }
                Text(description)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.appTextPrimary.opacity(0.92))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Short history

    @ViewBuilder
    private var shortHistorySection: some View {
        if let shortHistory = artwork?.shortHistory, !shortHistory.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.museumSpring) { historyExpanded.toggle() }
                    Haptics.tap()
                } label: {
                    HStack {
                        Text("Quick History").sectionLabel()
                        Spacer()
                        Image(systemName: historyExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(Color.appTextMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if historyExpanded {
                    Text(shortHistory)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appTextPrimary.opacity(0.88))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appSurface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    // MARK: - Creation story

    @ViewBuilder
    private var creationStorySection: some View {
        if let story = artwork?.creationStory, !story.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Origin").sectionLabel()
                Text(story)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appTextPrimary.opacity(0.88))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Quote

    @ViewBuilder
    private var quoteSection: some View {
        if let quote = artwork?.quote, !quote.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Inspiration").sectionLabel()
                    .padding(.bottom, 12)
                HStack(alignment: .top, spacing: 14) {
                    Text("\u{201C}")
                        .font(.system(size: 52, design: .serif).weight(.light))
                        .foregroundStyle(accent.opacity(0.6))
                        .offset(y: -8)
                    Text(quote)
                        .font(.system(size: 17, design: .serif).weight(.light))
                        .italic()
                        .foregroundStyle(Color.appTextPrimary)
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appSurface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accent.opacity(0.18), lineWidth: 0.5))
            }
        }
    }

    // MARK: - Fun facts with per-fact audio (Opsi 6)

    @ViewBuilder
    private var funFactsCard: some View {
        if let facts = artwork?.funFacts, !facts.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Did You Know").sectionLabel()
                    Spacer()
                    // Stop button when any fact is speaking
                    if speaker.speakingIndex != nil {
                        Button { speaker.stop() } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.pressable)
                        .transition(.opacity)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(facts.enumerated()), id: \.offset) { idx, fact in
                        HStack(alignment: .top, spacing: 10) {
                            Text("—").foregroundStyle(accent)
                            Text(fact)
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextSecondary)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            listenButton(text: fact, index: idx)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 18)
            }
        }
    }

    // MARK: - Love poems

    @ViewBuilder
    private var lovePoemsSection: some View {
        if let poems = artwork?.lovePoems, !poems.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Poetic Lines").sectionLabel()
                VStack(spacing: 12) {
                    ForEach(Array(poems.enumerated()), id: \.offset) { index, poem in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, design: .serif))
                                .foregroundStyle(accent)
                                .frame(width: 16)
                                .padding(.top, 2)
                            Text(poem)
                                .font(.system(size: 14, design: .serif).weight(.light))
                                .italic()
                                .foregroundStyle(Color.appTextPrimary.opacity(0.9))
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 16)
            }
        }
    }

    // MARK: - Romantic line (legacy)

    @ViewBuilder
    private var romanticLineSection: some View {
        let poems = artwork?.lovePoems ?? []
        if poems.isEmpty, let line = artwork?.romanticLine, !line.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Share the Love").sectionLabel()
                VStack(alignment: .leading, spacing: 14) {
                    Text(line)
                        .font(.system(size: 15, design: .serif).weight(.light))
                        .italic()
                        .foregroundStyle(Color.appTextPrimary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        UIPasteboard.general.string = line
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12, weight: .medium))
                            Text("Copy Line")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(accent.opacity(0.14)))
                    }
                    .buttonStyle(.pressable)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appSurface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accent.opacity(0.25), lineWidth: 0.5))
            }
        }
    }

    // MARK: - Artist story

    @ViewBuilder
    private var artistStorySection: some View {
        if let story = artwork?.artistStory, !story.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("About the Artist").sectionLabel()
                HStack(alignment: .top, spacing: 14) {
                    if let urlString = artistPortraitURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                    .overlay(Circle().strokeBorder(accent.opacity(0.4), lineWidth: 1))
                            } else {
                                Circle().fill(accent.opacity(0.15)).frame(width: 44, height: 44)
                            }
                        }
                    }
                    Text(story)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Action bar (favorite + ambient music + share)

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 12) {
            // Ambient music indicator strip (shown when playing)
            if ambientAudio.isPlaying {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(accent)
                    Text("Playing: \(ambientAudio.currentMovement) ambience")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                    Spacer()
                    Button { ambientAudio.stopPlayback() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.appTextMuted)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurface))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 14) {
                // Favorite
                Button { toggleFavorite() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .scaleEffect(heartScale)
                        Text(isFavorite ? "Saved" : "Save")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(isFavorite ? Color.appAccent : Color.appTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.appSurface))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder((isFavorite ? accent : Color.white).opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                // Share
                ShareLink(item: shareText) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.appSurface))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                }
                .accessibilityLabel("Share artwork")
            }
        }
    }

    // MARK: - Listen button helper (Opsi 6)

    private func listenButton(text: String, index: Int) -> some View {
        let isSpeaking = speaker.speakingIndex == index
        return Button {
            if isSpeaking {
                speaker.stop()
            } else {
                Haptics.tap()
                speaker.speak(text, index: index)
            }
        } label: {
            Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSpeaking ? accent : Color.appTextMuted)
                .frame(width: 32, height: 32)
                .background(Circle().fill(isSpeaking ? accent.opacity(0.15) : Color.appSurfaceUp))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(isSpeaking ? "Stop reading" : "Listen to this")
    }

    // MARK: - Helpers

    private var shareText: String {
        var parts = [result.displayTitle]
        if let artist = artwork?.artist, !artist.isEmpty { parts.append("by \(artist)") }
        if let location = artwork?.location, !location.isEmpty { parts.append("· \(location)") }
        parts.append("— identified with MuseumMate")
        return parts.joined(separator: " ")
    }

    private func toggleFavorite() {
        Haptics.impact(.light)
        historyStore.toggleFavorite(result)
        heartScale = 1.25
        withAnimation(reduceMotion ? nil : .museumSpring) { heartScale = 1.0 }
    }
}

struct ArtworkDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ArtworkDetailView(result: .preview)
                .environmentObject(ScanHistoryStore())
                .environmentObject(AmbientAudioService())
        }
        .preferredColorScheme(.dark)
    }
}
