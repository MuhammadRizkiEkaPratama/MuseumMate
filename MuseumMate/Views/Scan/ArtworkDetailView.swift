//
//  ArtworkDetailView.swift
//  MuseumMate
//
//  The detail screen — like opening a premium art book. Hero image,
//  museum-label identity card, confidence gauge, catalog copy, fun facts.
//

import SwiftUI

struct ArtworkDetailView: View {
    let result: ScanResult

    @EnvironmentObject private var historyStore: ScanHistoryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var image: UIImage?
    @State private var confidenceFill: Double = 0
    @State private var heartScale: CGFloat = 1

    private var artwork: Artwork? { result.artwork }
    private var detectedArtistInfo: Artist? { ArtistLibrary.artist(fromLabel: result.localArtist) }
    private var accent: Color { ArtistLibrary.accentColor(for: result.localArtist) }
    private var confidence: Double { artwork?.confidence ?? result.localConfidence }

    private var isFavorite: Bool {
        historyStore.scans.first { $0.id == result.id }?.isFavorite ?? result.isFavorite
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                heroImage
                    .fadeSlideIn()

                VStack(alignment: .leading, spacing: 28) {
                    identityCard
                        .fadeSlideIn(delay: 0.06)
                    confidenceSection
                        .fadeSlideIn(delay: 0.12)
                    descriptionSection
                        .fadeSlideIn(delay: 0.18)
                    creationStorySection
                        .fadeSlideIn(delay: 0.24)
                    quoteSection
                        .fadeSlideIn(delay: 0.30)
                    romanticLineSection
                        .fadeSlideIn(delay: 0.36)
                    funFactsCard
                        .fadeSlideIn(delay: 0.42)
                    actionBar
                        .fadeSlideIn(delay: 0.48)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if image == nil {
                image = ImageStore.loadImage(named: result.imageFileName)
            }
            let target = confidence
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) {
                confidenceFill = target
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroImage: some View {
        ZStack(alignment: .bottom) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 320)
            } else {
                Rectangle()
                    .fill(Color.appSurface)
                    .frame(height: 240)
                    .overlay(
                        Image(systemName: "photo.artframe")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(Color.appTextMuted)
                    )
            }

            // Vignette blending the artwork into the gallery wall.
            LinearGradient(
                colors: [.clear, Color.appBackground.opacity(0.9)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Identity

    @ViewBuilder
    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            artistBadge

            Text(result.displayTitle)
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Color.appAccent)
                .frame(width: 40, height: 2)

            if let artist = artwork?.artist, !artist.isEmpty {
                Text(artist)
                    .font(.title3.weight(.light))
                    .foregroundStyle(Color.appTextSecondary)
            }

            if let metadata = artwork?.metadataLine, !metadata.isEmpty {
                Text(metadata)
                    .font(.subheadline)
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

    @ViewBuilder
    private var artistBadge: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Detected Artist").sectionLabel()
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 3)
                    .cornerRadius(1.5)
                VStack(alignment: .leading, spacing: 2) {
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
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.12))
            )
        }
    }

    // MARK: - Confidence

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
                    Capsule()
                        .fill(Color.appSurfaceUp)
                    Capsule()
                        .fill(Color.appAccent)
                        .frame(width: proxy.size.width * confidenceFill)
                }
            }
            .frame(height: 8)
            .accessibilityElement()
            .accessibilityLabel("Confidence")
            .accessibilityValue("\(Int(confidence * 100)) percent")
        }
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionSection: some View {
        if let description = artwork?.description, !description.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("About").sectionLabel()
                Text(description)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.appTextPrimary.opacity(0.92))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                        .foregroundStyle(Color.appAccent.opacity(0.6))
                        .offset(y: -8)
                    Text(quote)
                        .font(.system(size: 17, design: .serif).weight(.light))
                        .italic()
                        .foregroundStyle(Color.appTextPrimary)
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.appAccent.opacity(0.18), lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Romantic line

    @ViewBuilder
    private var romanticLineSection: some View {
        if let line = artwork?.romanticLine, !line.isEmpty {
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
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(Color.appAccent.opacity(0.14))
                        )
                    }
                    .buttonStyle(.pressable)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.appAccent.opacity(0.25), lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Fun facts

    @ViewBuilder
    private var funFactsCard: some View {
        if let facts = artwork?.funFacts, !facts.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Did you know").sectionLabel()
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                        HStack(alignment: .top, spacing: 10) {
                            Text("—")
                                .foregroundStyle(Color.appAccent)
                            Text(fact)
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextSecondary)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 18)
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 14) {
            Button {
                toggleFavorite()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .scaleEffect(heartScale)
                    Text(isFavorite ? "Saved" : "Save")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(isFavorite ? Color.appAccent : Color.appTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            (isFavorite ? Color.appAccent : Color.white).opacity(0.15),
                            lineWidth: 0.5
                        )
                )
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

            ShareLink(item: shareText) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.appTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            }
            .accessibilityLabel("Share artwork")
        }
    }

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
        // Spring pop: jump up, settle back.
        heartScale = 1.25
        withAnimation(reduceMotion ? nil : .museumSpring) {
            heartScale = 1.0
        }
    }
}

struct ArtworkDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ArtworkDetailView(result: .preview)
                .environmentObject(ScanHistoryStore())
        }
        .preferredColorScheme(.dark)
    }
}
