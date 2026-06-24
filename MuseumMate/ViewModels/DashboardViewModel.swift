//
//  DashboardViewModel.swift
//  MuseumMate
//
//  Loads the daily painting (Met API), DeepSeek quote + trivia, "On This Day"
//  events, and nearby museums. All network calls run in parallel on first open.
//  Everything is cached per day so repeat visits are instant.
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
    @Published var generatedOnThisDayEvents: [ArtHistoryEvent] = []
    @Published var isGeneratingOnThisDay = false
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

    // MARK: - Cache keys

    private let quoteKey             = "museummate_daily_quote_v1"
    private let triviaKey            = "museummate_daily_trivia_v1"
    private let triviaStateKey       = "museummate_daily_trivia_state_v1"
    private let explanationsKey      = "museummate_daily_explanations_v1"
    private let generatedEventsKey   = "museummate_generated_onthisday_v1"

    // MARK: - Init

    init() {
        location.$userLocation
            .receive(on: RunLoop.main)
            .sink { [weak self] loc in
                guard let self, let loc else { return }
                self.nearbyMuseums = MuseumLibrary.nearest(to: loc, count: 5)
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

    /// Merged On This Day events — curated list first, DeepSeek-generated as fallback.
    var displayedOnThisDayEvents: [ArtHistoryEvent] {
        onThisDayEvents.isEmpty ? generatedOnThisDayEvents : onThisDayEvents
    }

    // MARK: - Load

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true

        // Local data — instant.
        restoreTriviaState()
        onThisDayEvents = Array(ArtHistoryLibrary.eventsForToday().prefix(4))
        explanations = DailyCache.load([UUID: String].self, key: explanationsKey) ?? [:]

        loadMuseums()
        await loadDailyContent()
    }

    private func loadMuseums() {
        isLoadingMuseums = true
        location.requestLocation()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self else { return }
            if self.nearbyMuseums.isEmpty {
                self.nearbyMuseums = MuseumLibrary.famousFallback
                self.isLoadingMuseums = false
            }
        }
    }

    private func loadDailyContent() async {
        // 1. Show fallback painting immediately — no blank card while Met API loads.
        if dailyPainting == nil { dailyPainting = MetObject.fallback }

        // 2. Populate quote/trivia from cache before any network call.
        if let q = DailyCache.load(String.self, key: quoteKey), !q.isEmpty { dailyQuote = q }
        if let t = DailyCache.load(TriviaQuestion.self, key: triviaKey) { dailyTrivia = t }

        // 3. Populate generated On This Day events from cache.
        if let cached = DailyCache.load([CachedEvent].self, key: generatedEventsKey) {
            generatedOnThisDayEvents = cached.map { $0.toEvent() }
        }

        let context = dailyPainting!
        isLoadingPainting = true

        // 4. All four tasks run in parallel.
        async let quoteFetch:     Void       = fetchQuoteIfNeeded(context)
        async let triviaFetch:    Void       = fetchTriviaIfNeeded(context)
        async let onThisDayGen:   Void       = generateOnThisDayIfNeeded()
        async let paintingResult: MetObject? = safeFetchPainting()

        _ = await (quoteFetch, triviaFetch, onThisDayGen)
        if let p = await paintingResult { dailyPainting = p }
        isLoadingPainting = false
    }

    private func safeFetchPainting() async -> MetObject? {
        do { return try await met.fetchDailyPainting() }
        catch {
            print("[Dashboard] painting fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Quote

    private func fetchQuoteIfNeeded(_ painting: MetObject) async {
        guard dailyQuote.isEmpty else { return }
        guard AppConfig.hasValidAPIKey else {
            print("[Dashboard] DeepSeek key missing — quote skipped")
            return
        }
        isLoadingQuote = true
        defer { isLoadingQuote = false }
        do {
            let quote = try await vision.generateArtworkQuote(painting: painting)
            if !quote.isEmpty {
                dailyQuote = quote
                DailyCache.save(quote, key: quoteKey)
            }
        } catch {
            print("[Dashboard] quote failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Trivia

    private func fetchTriviaIfNeeded(_ painting: MetObject) async {
        guard dailyTrivia == nil else { return }
        guard AppConfig.hasValidAPIKey else {
            print("[Dashboard] DeepSeek key missing — trivia skipped")
            return
        }
        isLoadingTrivia = true
        defer { isLoadingTrivia = false }
        do {
            let trivia = try await vision.generateDailyTrivia(painting: painting)
            dailyTrivia = trivia
            DailyCache.save(trivia, key: triviaKey)
        } catch {
            print("[Dashboard] trivia failed: \(error.localizedDescription)")
        }
    }

    // MARK: - On This Day DeepSeek fallback

    private func generateOnThisDayIfNeeded() async {
        guard onThisDayEvents.isEmpty, generatedOnThisDayEvents.isEmpty else { return }
        guard AppConfig.hasValidAPIKey else { return }

        isGeneratingOnThisDay = true
        defer { isGeneratingOnThisDay = false }

        let cal = Calendar.current
        let month = cal.component(.month, from: Date())
        let day   = cal.component(.day,   from: Date())

        do {
            let events = try await vision.generateOnThisDayFallback(month: month, day: day)
            generatedOnThisDayEvents = events
            DailyCache.save(events.map { CachedEvent(from: $0) }, key: generatedEventsKey)
        } catch {
            print("[Dashboard] On This Day generation failed: \(error.localizedDescription)")
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

// MARK: - Codable wrapper for ArtHistoryEvent (for DailyCache)

private struct CachedEvent: Codable {
    let month: Int
    let day: Int
    let year: Int
    let title: String
    let dateDescription: String
    let category: String

    init(from e: ArtHistoryEvent) {
        month = e.month; day = e.day; year = e.year
        title = e.title; dateDescription = e.dateDescription
        category = e.category.rawValue
    }

    func toEvent() -> ArtHistoryEvent {
        ArtHistoryEvent(
            month: month, day: day, year: year,
            title: title, dateDescription: dateDescription,
            category: ArtHistoryEvent.EventCategory(rawValue: category) ?? .discovery
        )
    }
}
