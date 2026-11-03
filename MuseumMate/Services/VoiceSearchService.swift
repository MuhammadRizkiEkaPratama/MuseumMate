//
//  VoiceSearchService.swift
//  MuseumMate
//
//  Wraps SFSpeechRecognizer + AVAudioEngine for live voice-to-text search.
//  Usage: inject as @StateObject, bind `transcript` to a search filter.
//

import Foundation
import Speech
import AVFoundation

@MainActor
final class VoiceSearchService: ObservableObject {

    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale.current)
        authStatus = SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Permission

    func requestPermissions() async {
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        authStatus = status
    }

    // MARK: - Start / stop

    func startListening() {
        guard authStatus == .authorized else {
            errorMessage = "Speech recognition not authorized."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer not available."
            return
        }
        guard !isListening else { return }

        do {
            try beginSession(recognizer: recognizer)
        } catch {
            errorMessage = "Could not start microphone."
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func clear() {
        transcript = ""
        errorMessage = nil
    }

    // MARK: - Private

    private func beginSession(recognizer: SFSpeechRecognizer) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
        errorMessage = nil

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in self.transcript = text }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in self.stopListening() }
            }
        }
    }
}
