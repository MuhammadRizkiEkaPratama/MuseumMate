//
//  ExploreView.swift
//  MuseumMate
//
//  The flagship live feature. The camera fills the screen; a floating badge
//  names the style in real time; "Scan This" runs the full identification.
//

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var historyStore: ScanHistoryStore
    @StateObject private var viewModel = ExploreViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if viewModel.permissionDenied {
                    permissionDeniedView
                } else {
                    cameraLayer
                    topWatermark
                    bottomControls
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: detailBinding) {
                if let result = viewModel.capturedResult {
                    ArtworkDetailView(result: result)
                }
            }
            .onAppear { viewModel.start() }
            .onDisappear { viewModel.stop() }
        }
    }

    // MARK: - Camera

    private var cameraLayer: some View {
        CameraPreviewView(session: viewModel.camera.session)
            .ignoresSafeArea()
    }

    // MARK: - Overlays

    private var topWatermark: some View {
        VStack {
            Text("MuseumMate")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.appTextPrimary)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 1)
                .padding(.top, 8)
            Spacer()
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: 18) {
            Spacer()

            StyleOverlayView(
                style: viewModel.currentStyle,
                confidence: viewModel.currentConfidence
            )

            scanButton
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var scanButton: some View {
        Button {
            Task { await viewModel.scanCurrentFrame(store: historyStore) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appAccent)
                if viewModel.isScanning {
                    PulsingDots()
                } else {
                    Text("Scan This")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.appBackground)
                }
            }
            .frame(height: 56)
        }
        .buttonStyle(.pressable)
        .disabled(viewModel.isScanning)
        .accessibilityLabel("Scan this artwork")
    }

    // MARK: - Permission denied

    private var permissionDeniedView: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.appTextMuted)
            Text("Camera access is off")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.appTextSecondary)
            Text("MuseumMate needs the camera to recognize artworks in real time. Enable it in Settings.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 36)

            Button {
                Haptics.tap()
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
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
    }

    // MARK: - Navigation

    private var detailBinding: Binding<Bool> {
        Binding(
            get: { viewModel.capturedResult != nil },
            set: { if !$0 { viewModel.clearCapture() } }
        )
    }
}

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreView()
            .environmentObject(ScanHistoryStore())
            .preferredColorScheme(.dark)
    }
}
