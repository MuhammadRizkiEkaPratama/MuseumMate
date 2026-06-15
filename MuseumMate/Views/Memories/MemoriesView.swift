//
//  MemoriesView.swift
//  MuseumMate
//
//  A photo journal of museum visits. New photos auto-link to scans taken
//  around the same time.
//

import SwiftUI

struct MemoriesView: View {
    @EnvironmentObject private var memoriesStore: MemoriesStore
    @EnvironmentObject private var historyStore: ScanHistoryStore
    @StateObject private var viewModel = MemoriesViewModel()

    @State private var activePhoto: MemoryPhoto?
    @State private var linkingPhoto: MemoryPhoto?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if memoriesStore.memories.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle("Museum Memories")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            Haptics.tap(); viewModel.showCamera = true
                        } label: { Image(systemName: "camera") }
                    }
                    Button {
                        Haptics.tap(); viewModel.showLibrary = true
                    } label: { Image(systemName: "photo") }
                }
            }
            .tint(Color.appAccent)
            .sheet(isPresented: $viewModel.showLibrary) {
                PhotoLibraryPicker { image in
                    viewModel.addPhoto(image, memoriesStore: memoriesStore, historyStore: historyStore)
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                CameraPicker { image in
                    viewModel.addPhoto(image, memoriesStore: memoriesStore, historyStore: historyStore)
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(item: $activePhoto) { photo in
                MemoryDetailView(photo: photo)
            }
            .sheet(item: $linkingPhoto) { photo in
                ScanLinkPicker(photo: photo)
            }
            .sheet(item: $viewModel.suggestion) { suggestion in
                linkSuggestionSheet(suggestion)
                    .presentationDetents([.height(240)])
            }
        }
    }

    // MARK: - Grid

    private var grid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(memoriesStore.memories) { photo in
                    MemoryCell(photo: photo)
                        .onTapGesture { activePhoto = photo }
                        .contextMenu {
                            Button { activePhoto = photo } label: {
                                Label("Edit Caption", systemImage: "pencil")
                            }
                            Button { linkingPhoto = photo } label: {
                                Label("Link to Artwork", systemImage: "link")
                            }
                            Button(role: .destructive) {
                                Haptics.impact(.medium)
                                memoriesStore.delete(photo)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.appTextMuted)
            Text("Capture moments from your museum visits.")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
            Text("Your photos link automatically to your scanned artworks.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Haptics.tap()
                viewModel.showLibrary = true
            } label: {
                Text("Add a Memory")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appBackground)
                    .padding(.horizontal, 24)
                    .frame(height: 46)
                    .background(Capsule().fill(Color.appAccent))
            }
            .buttonStyle(.pressable)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .fadeSlideIn()
    }

    // MARK: - Link suggestion sheet

    private func linkSuggestionSheet(_ suggestion: MemoriesViewModel.LinkSuggestion) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.appAccent)
            Text("This photo was taken around the time you scanned “\(suggestion.scan.displayTitle)”. Link them?")
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Button {
                    viewModel.dismissSuggestion(memoriesStore: memoriesStore)
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appSurface))
                }
                .buttonStyle(.pressable)

                Button {
                    viewModel.confirmSuggestion()
                } label: {
                    Text("Link")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appAccent))
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - Cell

private struct MemoryCell: View {
    let photo: MemoryPhoto
    @State private var image: UIImage?

    var body: some View {
        Color.appSurface
            .aspectRatio(1, contentMode: .fill)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(Color.appTextMuted)
                }
            }
            .overlay(alignment: .topTrailing) {
                if photo.isLinked {
                    Image(systemName: "link")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.appBackground)
                        .padding(5)
                        .background(Circle().fill(Color.appAccent))
                        .padding(6)
                }
            }
            .clipped()
            .task {
                if image == nil { image = ImageStore.loadImage(named: photo.imageFileName) }
            }
    }
}

// MARK: - Scan link picker

struct ScanLinkPicker: View {
    let photo: MemoryPhoto

    @EnvironmentObject private var memoriesStore: MemoriesStore
    @EnvironmentObject private var historyStore: ScanHistoryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if historyStore.scans.isEmpty {
                    EmptyStateView(symbol: "photo.artframe", message: "Scan an artwork first to link it here.")
                } else {
                    List {
                        ForEach(historyStore.scans) { scan in
                            Button {
                                Haptics.tap()
                                memoriesStore.link(memoryID: photo.id, to: scan.id, title: scan.displayTitle)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ScanThumbnail(result: scan, cornerRadius: 8)
                                        .frame(width: 44, height: 44)
                                    Text(scan.displayTitle)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appTextPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    if photo.linkedScanResultID == scan.id {
                                        Image(systemName: "checkmark").foregroundStyle(Color.appAccent)
                                    }
                                }
                            }
                            .listRowBackground(Color.appBackground)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                }
            }
            .navigationTitle("Link to a Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.tint(Color.appAccent)
                }
            }
        }
    }
}

struct MemoriesView_Previews: PreviewProvider {
    static var previews: some View {
        MemoriesView()
            .environmentObject(MemoriesStore())
            .environmentObject(ScanHistoryStore())
            .preferredColorScheme(.dark)
    }
}
