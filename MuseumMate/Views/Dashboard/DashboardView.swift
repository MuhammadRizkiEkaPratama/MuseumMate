//
//  DashboardView.swift
//  MuseumMate
//
//  The home screen — a daily art magazine: painting of the day, an AI
//  reflection, trivia, "On This Day", and nearby museums.
//

import SwiftUI

struct DashboardView: View {
    @Binding var selectedTab: AppTab

    @EnvironmentObject private var auth: AuthService
    @StateObject private var viewModel = DashboardViewModel()

    @State private var showPaintingSheet = false
    @State private var selectedMuseum: Museum?

    private var name: String {
        auth.currentUserName.isEmpty ? "Art Lover" : auth.currentUserName.split(separator: " ").first.map(String.init) ?? "Art Lover"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    greeting.fadeSlideIn()
                    dailyPaintingSection.fadeSlideIn(delay: 0.06)
                    quoteSection.fadeSlideIn(delay: 0.12)
                    triviaSection.fadeSlideIn(delay: 0.18)
                    onThisDaySection.fadeSlideIn(delay: 0.24)
                    nearbyMuseumsSection.fadeSlideIn(delay: 0.30)
                    scanCTASection.fadeSlideIn(delay: 0.36)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showPaintingSheet) {
                if let painting = viewModel.dailyPainting {
                    DailyPaintingSheet(painting: painting, quote: viewModel.dailyQuote)
                }
            }
            .sheet(item: $selectedMuseum) { museum in
                MuseumDetailSheet(museum: museum, userLocation: viewModel.location.userLocation)
            }
            .task { await viewModel.loadIfNeeded() }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(viewModel.greeting),")
                .font(.system(.title, design: .serif).weight(.light))
                .foregroundStyle(Color.appTextSecondary)
            Text(name)
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .foregroundStyle(Color.appTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 1. Daily painting

    @ViewBuilder
    private var dailyPaintingSection: some View {
        Button {
            guard viewModel.dailyPainting != nil else { return }
            Haptics.tap()
            showPaintingSheet = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                paintingImage
                paintingOverlay
                metBadge
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.pressable)
        .disabled(viewModel.dailyPainting == nil)
    }

    @ViewBuilder
    private var paintingImage: some View {
        if let painting = viewModel.dailyPainting {
            let preferredURL = URL(string: painting.primaryImageSmall.isEmpty
                ? painting.primaryImage
                : painting.primaryImageSmall)
            let fallbackURL = URL(string: painting.primaryImage)

            AsyncImage(url: preferredURL) { phase in
                switch phase {
                case .empty:
                    SkeletonView(cornerRadius: 20)

                case .success(let img):
                    img.resizable().scaledToFill()
                        .transition(.opacity.animation(.easeIn(duration: 0.3)))
                        .onAppear {
                            print("[Dashboard] painting loaded: \(painting.title), imageURL: \(painting.primaryImageSmall)")
                        }

                case .failure:
                    // Primary URL failed — try the full-size fallback.
                    AsyncImage(url: fallbackURL) { fallbackPhase in
                        switch fallbackPhase {
                        case .empty:
                            SkeletonView(cornerRadius: 20)
                        case .success(let img):
                            img.resizable().scaledToFill()
                                .transition(.opacity.animation(.easeIn(duration: 0.3)))
                                .onAppear {
                                    print("[Dashboard] painting loaded via fallback: \(painting.title), imageURL: \(painting.primaryImage)")
                                }
                        case .failure:
                            artworkUnavailablePlaceholder
                        @unknown default:
                            artworkUnavailablePlaceholder
                        }
                    }

                @unknown default:
                    SkeletonView(cornerRadius: 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            SkeletonView(cornerRadius: 20)
        }
    }

    private var artworkUnavailablePlaceholder: some View {
        Color.appSurface
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.appAccent)
                    Text("Artwork unavailable")
                        .font(.caption)
                        .foregroundStyle(Color.appTextMuted)
                }
            )
    }

    @ViewBuilder
    private var paintingOverlay: some View {
        if let painting = viewModel.dailyPainting {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.appBackground.opacity(0.92)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 88)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(painting.title)
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(painting.artistOrUnknown)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(1)
                    }
                    .padding(14)
                }
            }
        }
    }

    @ViewBuilder
    private var metBadge: some View {
        if viewModel.dailyPainting != nil {
            VStack {
                HStack {
                    Spacer()
                    Text("MET COLLECTION")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(0.8)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.appAccent.opacity(0.2)))
                        .padding(12)
                }
                Spacer()
            }
        }
    }

    // MARK: - 2. Quote

    @ViewBuilder
    private var quoteSection: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.appAccent.opacity(0.6)).frame(width: 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("\u{201C}")
                    .font(.system(size: 44, design: .serif))
                    .foregroundStyle(Color.appAccent)
                    .frame(height: 24, alignment: .top)
                if viewModel.isLoadingQuote && viewModel.dailyQuote.isEmpty {
                    SkeletonLines(count: 2)
                } else if !viewModel.dailyQuote.isEmpty {
                    Text(viewModel.dailyQuote)
                        .font(.system(.title3, design: .serif).italic())
                        .foregroundStyle(Color.appTextPrimary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                    if let title = viewModel.dailyPainting?.title {
                        Text("— AI reflection on \(title)")
                            .font(.caption)
                            .foregroundStyle(Color.appTextMuted)
                    }
                } else {
                    Text("A reflection will appear here.")
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(Color.appTextMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.appSurface)
        )
    }

    // MARK: - 3. Trivia

    @ViewBuilder
    private var triviaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Art Trivia").sectionLabel()

            if viewModel.isLoadingTrivia && viewModel.dailyTrivia == nil {
                VStack(spacing: 10) {
                    SkeletonLines(count: 2)
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonView(cornerRadius: 14).frame(height: 50)
                    }
                }
                .card(padding: 18)
            } else if let trivia = viewModel.dailyTrivia {
                triviaCard(trivia)
            } else {
                Text("Today's question is resting. Check back soon.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextMuted)
                    .card(padding: 18)
            }
        }
    }

    private func triviaCard(_ trivia: TriviaQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(trivia.question)
                .font(.system(.headline, design: .serif).weight(.medium))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(Array(trivia.options.enumerated()), id: \.offset) { index, option in
                    TriviaOptionRow(
                        letter: letter(index),
                        text: option,
                        state: optionState(index: index, trivia: trivia)
                    ) {
                        viewModel.answerTrivia(index)
                    }
                }
            }

            if viewModel.triviaAnswered {
                explanationCard(trivia)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.museumSpring, value: viewModel.triviaAnswered)
        .card(padding: 18)
    }

    private func explanationCard(_ trivia: TriviaQuestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isCorrect(trivia) ? "Correct" : "Not quite")
                .font(.caption.weight(.bold))
                .foregroundStyle(isCorrect(trivia) ? triviaGreen : Color.appDanger)
            Text(trivia.explanation)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appSurfaceUp)
        )
    }

    private func isCorrect(_ trivia: TriviaQuestion) -> Bool {
        guard let selected = viewModel.triviaSelectedIndex else { return false }
        return trivia.isCorrect(selected)
    }

    private func optionState(index: Int, trivia: TriviaQuestion) -> TriviaOptionRow.State {
        guard viewModel.triviaAnswered else { return .neutral }
        if index == trivia.correctIndex { return .correct }
        if index == viewModel.triviaSelectedIndex { return .wrong }
        return .dimmed
    }

    private func letter(_ index: Int) -> String {
        ["A", "B", "C", "D"][safe: index] ?? "?"
    }

    // MARK: - 4. On This Day

    @ViewBuilder
    private var onThisDaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("On This Day").sectionLabel()
                Spacer()
                Text(viewModel.todayLongString)
                    .font(.caption)
                    .foregroundStyle(Color.appTextMuted)
            }

            if viewModel.displayedOnThisDayEvents.isEmpty {
                if viewModel.isGeneratingOnThisDay {
                    VStack(alignment: .leading, spacing: 10) {
                        SkeletonLines(count: 2)
                    }
                    .card(padding: 18)
                } else {
                    Text("No recorded art history events today — but every day is a canvas.")
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(Color.appTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 18)
                }
            } else {
                ForEach(viewModel.displayedOnThisDayEvents) { event in
                    OnThisDayCard(
                        event: event,
                        isExpanded: viewModel.expandedEventID == event.id,
                        explanation: viewModel.explanations[event.id],
                        isLoading: viewModel.loadingExplanationID == event.id
                    ) {
                        viewModel.toggleEvent(event)
                    }
                }
            }
        }
    }

    // MARK: - 5. Nearby museums

    @ViewBuilder
    private var nearbyMuseumsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Museums Near You").sectionLabel()

            if viewModel.locationDenied {
                Text("Enable location for museums near you.")
                    .font(.caption)
                    .foregroundStyle(Color.appTextMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if viewModel.isLoadingMuseums && viewModel.nearbyMuseums.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonView(cornerRadius: 18)
                                .frame(width: 160, height: 200)
                        }
                    } else {
                        ForEach(viewModel.nearbyMuseums) { museum in
                            MuseumCard(
                                museum: museum,
                                distanceKm: viewModel.locationDenied ? nil : museum.distanceKm(from: viewModel.location.userLocation)
                            ) {
                                Haptics.tap()
                                selectedMuseum = museum
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 6. Scan CTA

    private var scanCTASection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.title)
                    .foregroundStyle(Color.appAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Discover an artwork")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("Point your camera and let its story unfold.")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer(minLength: 0)
            }

            Button {
                Haptics.impact(.medium)
                selectedTab = .scan
            } label: {
                Text("Open Scanner")
                    .font(.headline)
                    .foregroundStyle(Color.appBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.appAccent)
                    )
            }
            .buttonStyle(.pressable)
        }
        .card(padding: 18)
    }

    private let triviaGreen = Color(hex: "#3FB27F")
}

// MARK: - Trivia option row

struct TriviaOptionRow: View {
    enum State { case neutral, correct, wrong, dimmed }

    let letter: String
    let text: String
    let state: State
    let action: () -> Void

    private let green = Color(hex: "#3FB27F")

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(letter)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(letterColor)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(letterBackground))

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if state == .correct {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(green)
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.appDanger)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.pressable)
        .disabled(state != .neutral)
        .animation(.museumSpring, value: state)
    }

    private var background: Color {
        switch state {
        case .neutral, .dimmed: return Color.appSurfaceUp
        case .correct: return green.opacity(0.15)
        case .wrong: return Color.appDanger.opacity(0.1)
        }
    }
    private var borderColor: Color {
        switch state {
        case .correct: return green.opacity(0.4)
        case .wrong: return Color.appDanger.opacity(0.4)
        default: return Color.white.opacity(0.05)
        }
    }
    private var textColor: Color {
        state == .dimmed ? Color.appTextMuted : Color.appTextPrimary
    }
    private var letterColor: Color {
        state == .dimmed ? Color.appTextMuted : Color.appAccent
    }
    private var letterBackground: Color {
        state == .dimmed ? Color.appSurface : Color.appAccent.opacity(0.16)
    }
}

// MARK: - On This Day card

struct OnThisDayCard: View {
    let event: ArtHistoryEvent
    let isExpanded: Bool
    let explanation: String?
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: action) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: event.category.symbol)
                        .font(.title3)
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: String(event.year))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.appAccent)
                        Text(event.title)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.appTextPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.appTextMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)

            if isExpanded {
                Group {
                    if isLoading && explanation == nil {
                        SkeletonLines(count: 2)
                    } else if let explanation {
                        Text(explanation)
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Couldn't load more right now.")
                            .font(.caption)
                            .foregroundStyle(Color.appTextMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
            }
        }
        .card(padding: 16)
    }
}

// MARK: - Museum card

struct MuseumCard: View {
    let museum: Museum
    let distanceKm: Double?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "building.columns")
                    .font(.title3)
                    .foregroundStyle(Color.appAccent)

                Text(museum.name)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(museum.city), \(museum.country)")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextMuted)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let distanceKm {
                    Text(Museum.formattedDistance(distanceKm))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.appAccent.opacity(0.16)))
                }

                Text("Home of \(museum.iconicWork)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appTextMuted)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(width: 160, height: 200, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Safe index

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
