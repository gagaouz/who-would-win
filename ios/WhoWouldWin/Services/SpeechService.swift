import AVFoundation
import Speech
import SwiftUI

@MainActor
final class SpeechService: NSObject, ObservableObject {

    // MARK: - Dictation state
    @Published var isListening = false
    @Published var transcript = ""
    @Published var dictationError: String?

    // MARK: - TTS state
    @Published var isSpeaking = false

    // MARK: - Private
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    /// Auto-stops the mic after 1.5 s of silence (no new partial results).
    private var silenceStopItem: DispatchWorkItem?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Dictation

    func startListening() {
        guard !isListening else { return }
        // Clear any stale error so a fresh attempt starts clean.
        dictationError = nil

        guard speechRecognizer?.isAvailable == true else {
            dictationError = "Voice typing isn't available right now. You can type the name instead."
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            // Callbacks arrive on an arbitrary background thread — dispatch to main.
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard status == .authorized else {
                    self.dictationError = "Speech recognition not authorized."
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        guard granted else {
                            self.dictationError = "Microphone access denied."
                            return
                        }
                        self.beginRecognition()
                    }
                }
            }
        }
    }

    func stopListening() {
        silenceStopItem?.cancel()
        silenceStopItem = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    private func beginRecognition() {
        stopListening()

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        // Kids privacy: a child's voice must stay ON DEVICE — the privacy
        // policy promises audio never leaves the phone, so we never fall back
        // to Apple's server-based recognition. If this device can't do
        // on-device recognition, voice search is unavailable (typing works).
        guard speechRecognizer?.supportsOnDeviceRecognition == true else {
            dictationError = "Voice search isn't available on this device — type the name instead!"
            stopListening()
            return
        }
        recognitionRequest.requiresOnDeviceRecognition = true

        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
                // Reset silence timer — stop 1.5 s after the last word lands.
                self.silenceStopItem?.cancel()
                let item = DispatchWorkItem { [weak self] in self?.stopListening() }
                self.silenceStopItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
            }
            if let error {
                // Only show a message if we ended up with nothing usable. A
                // user-initiated stop (or our own silence-timeout cancel) also
                // reports an error here, but by then we usually have a transcript,
                // so we stay quiet in that case to avoid nagging.
                if self.transcript.trimmingCharacters(in: .whitespaces).isEmpty {
                    self.dictationError = "Didn't catch that — tap the mic to try again, or type the name."
                    SpeechService.logRecognitionError(error)
                }
                self.stopListening()
            } else if result?.isFinal == true {
                self.stopListening()
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            dictationError = "Couldn't start the microphone — try again, or type the name."
            SpeechService.logRecognitionError(error)
            stopListening()
        }
    }

    /// Logs a recognition/audio error without leaking the child's transcript.
    nonisolated private static func logRecognitionError(_ error: Error) {
        let ns = error as NSError
        print("SpeechService error: \(ns.domain) #\(ns.code)")
    }

    // MARK: - Text-to-speech

    func speak(_ text: String) {
        // Respect user's narration toggle
        guard UserSettings.shared.narrationEnabled else { return }

        // Toggle off if already speaking
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            return
        }

        // Deactivate any leftover recording session first
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Simple playback — .playback category overrides the silent switch
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        // Prefer the highest-quality on-device neural voice available.
        // "Siri" voices (com.apple.ttsbundle.siri_*) and the enhanced/premium
        // variants sound far more natural than the default compact voice.
        utterance.voice = Self.bestEnglishVoice()
        utterance.rate = 0.50
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - Voice selection

    /// True if the device has any Enhanced or Premium en-* voice already downloaded.
    /// Compact/default voices are robotic — we only count the neural tiers.
    static var hasHighQualityVoice: Bool {
        if #available(iOS 16.0, *) {
            return AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language.hasPrefix("en") }
                .contains { $0.quality == .premium || $0.quality == .enhanced }
        }
        return false
    }

    /// Returns the most natural available English voice, in priority order:
    /// 1. Premium (neural) voices — the best quality, downloaded on some devices
    /// 2. Enhanced voices — better than compact, usually pre-installed
    /// 3. Any en-US voice as a final fallback
    private static func bestEnglishVoice() -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }

        // Quality tiers introduced in iOS 16+
        if #available(iOS 16.0, *) {
            if let premium = all.first(where: { $0.quality == .premium }) { return premium }
            if let enhanced = all.first(where: { $0.quality == .enhanced }) { return enhanced }
        }

        // Fallback: any en-US voice
        return AVSpeechSynthesisVoice(language: "en-US")
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
