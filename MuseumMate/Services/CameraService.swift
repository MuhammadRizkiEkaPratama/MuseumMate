//
//  CameraService.swift
//  MuseumMate
//
//  AVCaptureSession with throttled frame delivery for the live Explore
//  overlay. Delivers roughly 2 fps of CGImages to the classifier to save
//  battery, and keeps the latest frame for "Scan This".
//

import AVFoundation
import CoreImage
import UIKit

final class CameraService: NSObject, ObservableObject {
    @Published var permissionDenied = false
    @Published var isRunning = false

    let session = AVCaptureSession()

    /// Called on a background queue with ~2 fps of frames.
    var onFrame: ((CGImage) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "museummate.camera.session")
    private let videoQueue = DispatchQueue(label: "museummate.camera.video")
    private let ciContext = CIContext()

    private var isConfigured = false
    private var frameCounter = 0
    private let throttle = 15           // deliver every 15th frame (~2 fps)
    private let latestLock = NSLock()
    private var latestFrame: CGImage?

    // MARK: - Lifecycle

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.permissionDenied = true }
                return
            }
            DispatchQueue.main.async { self.permissionDenied = false }
            self.sessionQueue.async {
                self.configureIfNeeded()
                if !self.session.isRunning {
                    self.session.startRunning()
                    DispatchQueue.main.async { self.isRunning = true }
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async { self.isRunning = false }
            }
        }
    }

    /// The most recent frame, as a UIImage, for the full scan pipeline.
    func captureCurrentFrame() -> UIImage? {
        latestLock.lock()
        let frame = latestFrame
        latestLock.unlock()
        guard let frame else { return nil }
        return UIImage(cgImage: frame)
    }

    // MARK: - Configuration

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()

        // VGA preset is plenty for classification and faster than full res.
        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        }

        // Back camera input.
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            configureFocus(device)
        }

        // Frame output.
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        if let connection = videoOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        session.commitConfiguration()
        isConfigured = true
    }

    private func configureFocus(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = true
        }
        device.unlockForConfiguration()
    }
}

// MARK: - Frame delivery

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCounter &+= 1
        guard frameCounter % throttle == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        latestLock.lock()
        latestFrame = cgImage
        latestLock.unlock()

        onFrame?(cgImage)
    }
}
