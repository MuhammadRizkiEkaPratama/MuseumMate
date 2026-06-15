//
//  CameraPreviewView.swift
//  MuseumMate
//
//  Wraps AVCaptureVideoPreviewLayer. On the Simulator (no camera) it shows
//  a calm placeholder instead.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: View {
    let session: AVCaptureSession

    var body: some View {
        #if targetEnvironment(simulator)
        simulatorPlaceholder
        #else
        PreviewLayerView(session: session)
        #endif
    }

    private var simulatorPlaceholder: some View {
        ZStack {
            Color.appSurface
            VStack(spacing: 14) {
                Image(systemName: "photo.artframe")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(Color.appTextMuted)
                Text("Camera not available in Simulator")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }
}

private struct PreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
