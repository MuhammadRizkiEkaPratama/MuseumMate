//
//  HistoryView.swift
//  MuseumMate
//
//  Past scans as a clean gallery-catalog list. Grouped by recency once
//  there are enough entries. Swipe to delete, with confirmation.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: ScanHistoryStore
    @State private var pendingDelete: ScanResult?

    private var sections: [HistorySection] {
        HistorySection.group(historyStore.scans)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if historyStore.scans.isEmpty {
                    EmptyStateView(
                        symbol: "photo.artframe",
                        message: "Your discoveries will live here."
                    )
                } else {
                    list
                }
            }
            .navigationTitle("History")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        }
    }

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

    private var accent: Color { ArtStyleLibrary.accentColor(for: result.displayStyle) }

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

    /// Buckets by recency only when there are more than five scans.
    static func group(_ scans: [ScanResult]) -> [HistorySection] {
        guard scans.count > 5 else {
            return scans.isEmpty ? [] : [HistorySection(title: "All", items: scans)]
        }

        let calendar = Calendar.current
        let now = Date()
        var today: [ScanResult] = []
        var week: [ScanResult] = []
        var earlier: [ScanResult] = []

        for scan in scans {
            if calendar.isDateInToday(scan.date) {
                today.append(scan)
            } else if let days = calendar.dateComponents([.day], from: scan.date, to: now).day, days < 7 {
                week.append(scan)
            } else {
                earlier.append(scan)
            }
        }

        var result: [HistorySection] = []
        if !today.isEmpty { result.append(HistorySection(title: "Today", items: today)) }
        if !week.isEmpty { result.append(HistorySection(title: "This Week", items: week)) }
        if !earlier.isEmpty { result.append(HistorySection(title: "Earlier", items: earlier)) }
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
