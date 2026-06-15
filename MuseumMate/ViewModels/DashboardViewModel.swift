//
//  DashboardViewModel.swift
//  MuseumMate
//
//  Loads the daily painting (Met API), GPT quote + trivia, "On This Day"
//  events, and nearby museums. Everything is cached per day so repeat
//  visits are instant and GPT is called at most once per day per item.
//

import SwiftUI
import Combine
import CoreLocation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var dailyPainting: MetObject?
    @Published var dailyQuote = ""
    @Published var dailyTrivia: TriviaQuestion?

    @Published var onThisDayEvents: [ArtHistoryEvent] = []
    @Published var explanations: [UUID: String] = [:]
    @Published var expandedEventID: UUID?
    @Published var loadingExplanationID: UUID?

    @Published var nearbyMuseums: [Museum] = []
    @Published var locationDenied = false

    @Published var isLoadingPainting = false
    @Published var isLoadingQuote = false
    @Published var isLoadingTrivia = false
    @Published var isLoadingMuseums = false

    @Published var triviaAnswered = false
    @Published var triviaSelectedIndex: Int?

    @Published var errorMessage: String?

    private let met = MetMuseumService()
    private let vision = VisionService()
    let location = LocationService()

    private var cancellables = Set<AnyCancellable>()
    private var didLoad = false

    // Per-day cache keys.
    private let quoteKey = "museummate_daily_quote_v1"
    private let triviaKey = "museummate_daily_trivia_v1"
    private let triviaStateKey = "museummate_daily_trivia_state_v1"
    private let explanationsKey = "museummate_daily_explanations_v1"

    init() {
        location.$userLocation
            .receive(on: RunLoop.main)
            .sink { [weak self] loc in
                guard let self, let loc else { return }
                self.nearbyMuseums = MuseumLibrary.nearest(to: loc, count: 3)
                self.isLoadingMuseums = false
            }
            .store(in: &cancellables)

        location.$authorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                let denied = (status == .denied || status == .restricted)
                self.locationDenied = denied
                if denied {
                    self.nearbyMuseums = MuseumLibrary.famousFallback
                    self.isLoadingMuseums = false
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Greeting

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var todayLongString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Load

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true

        restoreTriviaState()
        onThisDayEvents = Array(ArtHistoryLibrary.eventsForToday().prefix(4))
        explanations = DailyCache.load([UUID: String].self, key: explanationsKey) ?? [:]

        loadMuseums()
        await loadDailyContent()
    }

    private func loadMuseums() {
        isLoadingMuseums = true
        location.requestLocation()
        // Fallback so the section never hangs (e.g. Simulator with no fix).
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self else { return }
            if self.nearbyMuseums.isEmpty {
                self.nearbyMuseums = MuseumLibrary.famousFallback
                self.isLoadingMuseums = false
            }
        }
    }

    private func loadDailyContent() async {
        isLoadingPainting = true
        do {
            let painting = try await met.fetchDailyPainting()
            dailyPainting = painting
            isLoadingPainting = false
            await loadQuoteAndTrivia(for: painting)
        } catch {
            isLoadingPainting = false
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't load today's painting."
        }
    }

    private func loadQuoteAndTrivia(for painting: MetObject) async {
        // Serve from cache first.
        if let cachedQuote = DailyCache.load(String.self, key: quoteKey) {
            dailyQuote = cachedQuote
        }
        if let cachedTrivia = DailyCache.load(TriviaQuestion.self, key: triviaKey) {
            dailyTrivia = cachedTrivia
        }

        async let quoteDone: Void = fetchQuoteIfNeeded(painting)
        async let triviaDone: Void = fetchTriviaIfNeeded(painting)
        _ = await (quoteDone, triviaDone)
    }

    private func fetchQuoteIfNeeded(_ painting: MetObject) async {
        guard dailyQuote.isEmpty else { return }
        isLoadingQuote = true
        defer { isLoadingQuote = false }
        if let quote = try? await vision.generateArtworkQuote(painting: painting), !quote.isEmpty {
            dailyQuote = quote
            DailyCache.save(quote, key: quoteKey)
        }
    }

    private func fetchTriviaIfNeeded(_ painting: MetObject) async {
        guard dailyTrivia == nil else { return }
        isLoadingTrivia = true
        defer { isLoadingTrivia = false }
        if let trivia = try? await vision.generateDailyTrivia(painting: painting) {
            dailyTrivia = trivia
            DailyCache.save(trivia, key: triviaKey)
        }
    }

    // MARK: - Trivia answering

    func answerTrivia(_ index: Int) {
        guard !triviaAnswered, let trivia = dailyTrivia else { return }
        triviaSelectedIndex = index
        triviaAnswered = true
        Haptics.notification(trivia.isCorrect(index) ? .success : .error)
        DailyCache.save(TriviaState(answered: true, selectedIndex: index), key: triviaStateKey)
    }

    private func restoreTriviaState() {
        guard let state = DailyCache.load(TriviaState.self, key: triviaStateKey) else { return }
        triviaAnswered = state.answered
        triviaSelectedIndex = state.selectedIndex
    }

    private struct TriviaState: Codable {
        let answered: Bool
        let selectedIndex: Int?
    }

    // MARK: - On This Day expansion

    func toggleEvent(_ event: ArtHistoryEvent) {
        if expandedEventID == event.id {
            withAnimation(.museumSpring) { expandedEventID = nil }
            return
        }
        withAnimation(.museumSpring) { expandedEventID = event.id }
        guard explanations[event.id] == nil else { return }

        loadingExplanationID = event.id
        Task { [weak self] in
            guard let self else { return }
            let text = (try? await self.vision.generateOnThisDayExplanation(event: event)) ?? ""
            self.loadingExplanationID = nil
            guard !text.isEmpty else { return }
            self.explanations[event.id] = text
            DailyCache.save(self.explanations, key: self.explanationsKey)
        }
    }
}

// MARK: - Per-day cache

private enum DailyCache {
    private static let defaults = UserDefaults.standard

    private struct Dated<T: Codable>: Codable {
        let date: String
        let value: T
    }

    static func save<T: Codable>(_ value: T, key: String) {
        let wrapper = Dated(date: MetMuseumService.todayString(), value: value)
        if let data = try? JSONEncoder().encode(wrapper) {
            defaults.set(data, forKey: key)
        }
    }

    static func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        guard
            let data = defaults.data(forKey: key),
            let wrapper = try? JSONDecoder().decode(Dated<T>.self, from: data),
            wrapper.date == MetMuseumService.todayString()
        else { return nil }
        return wrapper.value
    }
}
