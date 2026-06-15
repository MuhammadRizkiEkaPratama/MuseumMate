//
//  ScanView.swift
//  MuseumMate
//
//  The scan experience: an elegant frame placeholder, then a preview of
//  the chosen work, then a living progress state, then the detail screen.
//

import SwiftUI

struct ScanView: View {
    @EnvironmentObject private var historyStore: ScanHistoryStore
    @StateObject private var viewModel = ScanViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showDetail = false
    @State private var framePulse = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        header
                        artFrame
                        controls
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(isPresented: $showDetail) {
                if let result = viewModel.currentResult {
                    ArtworkDetailView(result: result)
                }
            }
            .sheet(isPresented: $showLibrary) {
                PhotoLibraryPicker { image in select(image) }
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in select(image) }
                    .ignoresSafeArea()
            }
            .onChange(of: viewModel.phase) { phase in
                if phase == .complete { showDetail = true }
            }
            .onAppear { framePulse = true }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 6) {
            Text("Identify an Artwork")
                .font(.system(.title2, design: .serif).weight(.regular))
                .foregroundStyle(Color.appTextPrimary)
            Text("Capture or import a photo to reveal its story.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .fadeSlideIn()
    }

    // MARK: - The frame (state-aware)

    @ViewBuilder
    private var artFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appSurface)

            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        if viewModel.isScanning { scanningOverlay }
                    }
            } else {
                emptyFrameContent
            }
        }
        .frame(height: 380)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    Color.appAccent.opacity(viewModel.selectedImage == nil ? 0.4 : 0.15),
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: viewModel.selectedImage == nil ? [7, 6] : []
                    )
                )
                .opacity(viewModel.selectedImage == nil && framePulse && !reduceMotion ? 0.5 : 1)
                .animation(
                    viewModel.selectedImage == nil && !reduceMotion
                        ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                        : .default,
                    value: framePulse
                )
        )
        .fadeSlideIn(delay: 0.06)
    }

    private var emptyFrameContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.artframe")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(Color.appAccent.opacity(0.8))
            Text("Your canvas awaits")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var scanningOverlay: some View {
        ZStack {
            Color.appBackground.opacity(0.55)
            LoadingView(message: viewModel.phase.label)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Controls (state-aware)

    @ViewBuilder
    private var controls: some View {
        if case .failed(let message) = viewModel.phase {
            errorCard(message)
                .fadeSlideIn()
        } else if viewModel.isScanning {
            EmptyView()
        } else if viewModel.selectedImage != nil {
            identifyButton
                .fadeSlideIn(delay: 0.12)
        } else {
            sourceButtons
                .fadeSlideIn(delay: 0.12)
        }
    }

    private var sourceButtons: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap()
                showLibrary = true
            } label: {
                primaryLabel("Photo Library", icon: "photo.on.rectangle")
            }
            .buttonStyle(.pressable)

            Button {
                Haptics.tap()
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    showLibrary = true
                }
            } label: {
                ghostLabel("Camera", icon: "camera")
            }
            .buttonStyle(.pressable)
        }
    }

    private var identifyButton: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.impact(.medium)
                guard let image = viewModel.selectedImage else { return }
                Task { await viewModel.scan(image: image, store: historyStore) }
            } label: {
                primaryLabel("Identify Artwork", icon: "sparkle.magnifyingglass")
            }
            .buttonStyle(.pressable)

            Button {
                Haptics.tap()
                viewModel.reset()
            } label: {
                Text("Choose a different photo")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .buttonStyle(.pressable)
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(Color.appDanger)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                Haptics.impact(.medium)
                guard let image = viewModel.selectedImage else { return }
                Task { await viewModel.scan(image: image, store: historyStore) }
            } label: {
                primaryLabel("Try Again", icon: "arrow.clockwise")
            }
            .buttonStyle(.pressable)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 20)
    }

    // MARK: - Label builders

    private func primaryLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title).font(.headline)
        }
        .foregroundStyle(Color.appBackground)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appAccent)
        )
    }

    private func ghostLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title).font(.headline)
        }
        .foregroundStyle(Color.appTextPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Actions

    private func select(_ image: UIImage) {
        viewModel.reset()
        viewModel.selectedImage = image
    }
}

struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        ScanView()
            .environmentObject(ScanHistoryStore())
            .preferredColorScheme(.dark)
    }
}
