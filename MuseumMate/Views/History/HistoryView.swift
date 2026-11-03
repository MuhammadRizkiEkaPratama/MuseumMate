//
//  HistoryView.swift
//  MuseumMate
//
//  Past scans as a clean gallery-catalog list. Grouped by recency once
//  there are enough entries. Swipe to delete with confirmation.
//  Opsi 5: Voice search — tap the mic button in the nav bar to speak a
//  title or artist name; results filter in real time.
//

import SwiftUI
import Speech

struct HistoryView: View {
    @EnvironmentObject private var historyStore: ScanHistoryStore
    @StateObject private var voiceSearch = VoiceSearchService()
    @State private var pendingDelete: ScanResult?
    @State private var searchText = ""

    // Filtered scans: voice transcript overrides manual text when mic is active
    private var activeQuery: String {
        voiceSearch.isListening || !voiceSearch.transcript.isEmpty
            ? voiceSearch.transcript
            : searchText
    }

    private var filteredScans: [ScanResult] {
        let q = activeQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return historyStore.scans }
        return historyStore.scans.filter {
            $0.displayTitle.lowercased().contains(q)
            || ($0.artwork?.artist.lowercased().contains(q) ?? false)
            || $0.displayStyle.lowercased().contains(q)
        }
    }

    private var sections: [HistorySection] {
        HistorySection.group(filteredScans)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Voice search status strip
                    if voiceSearch.isListening || !voiceSearch.transcript.isEmpty {
                        voiceSearchStrip
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if historyStore.scans.isEmpty {
                        EmptyStateView(
                            symbol: "photo.artframe",
                            message: "Your discoveries will live here."
                        )
                    } else if filteredScans.isEmpty {
                        EmptyStateView(
                            symbol: "magnifyingglass",
                            message: "No scans match \"\(activeQuery)\"."
                        )
                    } else {
                        list
                    }
                }
            }
            .navigationTitle("History")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    micButton
                }
            }
            .confirmationDialog(
                "Delete this scan?",
                isPresented: deleteBinding,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let pendingDelete {
                        Haptics.impact(.medium)
                        historyStore.delete(pendingDelete)
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This removes the scan and its saved image.")
            }
            .task {
                if voiceSearch.authStatus == .notDetermined {
                    await voiceSearch.requestPermissions()
                }
            }
            // Keep searchText in sync when transcript updates
            .onChange(of: voiceSearch.transcript) { newValue in
                searchText = newValue
            }
        }
    }

    // MARK: - Mic button

    private var micButton: some View {
        Button {
            withAnimation(.museumSpring) {
                if voiceSearch.isListening {
                    voiceSearch.stopListening()
                } else {
                    voiceSearch.clear()
                    voiceSearch.startListening()
                    Haptics.tap()
                }
            }
        } label: {
            Image(systemName: voiceSearch.isListening ? "mic.fill" : "mic")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(voiceSearch.isListening ? Color.appAccent : Color.appTextSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(
                        voiceSearch.isListening
                            ? Color.appAccent.opacity(0.15)
                            : Color.appSurface
                    )
                )
        }
        .buttonStyle(.pressable)
        .disabled(voiceSearch.authStatus == .denied || voiceSearch.authStatus == .restricted)
        .accessibilityLabel(voiceSearch.isListening ? "Stop voice search" : "Voice search")
    }

    // MARK: - Voice search strip

    private var voiceSearchStrip: some View {
        HStack(spacing: 10) {
            if voiceSearch.isListening {
                // Animated listening indicator
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.appAccent)
                            .frame(width: 3, height: CGFloat.random(in: 8...18))
                            .animation(
                                .easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(i) * 0.15),
                                value: voiceSearch.isListening
                            )
                    }
                }
                .frame(width: 20, height: 20)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.appAccent)
            }

            Text(voiceSearch.isListening
                 ? (voiceSearch.transcript.isEmpty ? "Listening\u{2026}" : voiceSearch.transcript)
                 : "\"\(voiceSearch.transcript)\"")
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation(.museumSpring) {
                    voiceSearch.stopListening()
                    voiceSearch.clear()
                    searchText = ""
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.appTextMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.appSurface)
        .overlay(
            Rectangle()
                .fill(Color.appAccent.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { result in
                        row(for: result)
                    }
                } header: {
                    if sections.count > 1 {
                        Text(section.title).sectionLabel()
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    private func row(for result: ScanResult) -> some View {
        ZStack {
            NavigationLink {
                ArtworkDetailView(result: result)
            } label: { EmptyView() }
            .opacity(0)

            HistoryRow(result: result)
        }
        .listRowBackground(Color.appBackground)
        .listRowSeparatorTint(Color.white.opacity(0.06))
        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = result
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let result: ScanResult

    private var accent: Color { ArtistLibrary.accentColor(for: result.displayStyle) }

    var body: some View {
        HStack(spacing: 14) {
            ScanThumbnail(result: result)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 5) {
                Text(result.displayTitle)
                    .font(.system(.headline, design: .serif).weight(.regular))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(result.displayStyle)
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.8)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent.opacity(0.16)))

                    if result.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.appAccent)
                    }
                }

                Text(result.formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.appTextMuted)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.appTextMuted)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Grouping

private struct HistorySection: Identifiable {
    let id = UUID()
    let title: String
    let items: [ScanResult]

    static func group(_ scans: [ScanResult]) -> [HistorySection] {
        guard scans.count > 5 else {
            return scans.isEmpty ? [] : [HistorySection(title: "All", items: scans)]
        }

        let calendar = Calendar.current
        let now = Date()
        var today: [ScanResult] = []
        var week:  [ScanResult] = []
        var earlier: [ScanResult] = []

        for scan in scans {
            if calendar.isDateInToday(scan.date) {
                today.append(scan)
            } else if let days = calendar.dateComponents([.day], from: scan.date, to: now).day,
                      days < 7 {
                week.append(scan)
            } else {
                earlier.append(scan)
            }
        }

        var result: [HistorySection] = []
        if !today.isEmpty   { result.append(HistorySection(title: "Today",     items: today)) }
        if !week.isEmpty    { result.append(HistorySection(title: "This Week", items: week)) }
        if !earlier.isEmpty { result.append(HistorySection(title: "Earlier",   items: earlier)) }
        return result
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(ScanHistoryStore())
            .preferredColorScheme(.dark)
    }
}
