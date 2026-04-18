import AVFoundation

/// Wraps AVSpeechSynthesizer for hands-free battle narration in CarPlay.
final class CarPlaySpeaker: NSObject {

    private let synthesizer = AVSpeechSynthesizer()

    /// Speak text, interrupting any current speech immediately.
    func speak(_ text: String, rate: Float = 0.47) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate  = rate
        utterance.pitchMultiplier  = 1.08
        utterance.postUtteranceDelay = 0.15
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
