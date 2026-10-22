import AVFoundation
import Observation
import Speech

/// Listening in Hindi with Apple's speech recogniser, and speaking answers back.
@Observable final class Voice: NSObject {
    enum Problem: Equatable { case denied, unavailable }

    private(set) var transcript = ""
    private(set) var listening = false
    private(set) var startedAt = Date()
    /// Recent loudness, 0...1, for the waveform in the pill.
    private(set) var levels: [Float] = Array(repeating: 0, count: 18)

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "hi-IN"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silence: Timer?
    private var onDone: ((String) -> Void)?
    private let synth = AVSpeechSynthesizer()

    func start(onDone: @escaping (String) -> Void, onProblem: @escaping (Problem) -> Void) {
        synth.stopSpeaking(at: .immediate)
        SFSpeechRecognizer.requestAuthorization { status in
            AVAudioApplication.requestRecordPermission { mic in
                DispatchQueue.main.async {
                    guard status == .authorized, mic else { return onProblem(.denied) }
                    guard let r = self.recognizer, r.isAvailable else { return onProblem(.unavailable) }
                    do { try self.begin(r, onDone) } catch { onProblem(.unavailable) }
                }
            }
        }
    }

    private func begin(_ r: SFSpeechRecognizer, _ done: @escaping (String) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if r.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req
        transcript = ""; onDone = done; startedAt = Date(); listening = true
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [weak self] buf, _ in
            req.append(buf)
            guard let ch = buf.floatChannelData?[0] else { return }
            let n = Int(buf.frameLength)
            var sum: Float = 0
            for i in 0..<n { sum += ch[i] * ch[i] }
            let rms = min(1, sqrt(sum / Float(max(n, 1))) * 12)
            DispatchQueue.main.async { self?.levels.removeFirst(); self?.levels.append(rms) }
        }
        engine.prepare()
        try engine.start()
        task = r.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.armSilenceTimer()
                    if result.isFinal { self.finish() }
                }
                if error != nil { self.finish() }
            }
        }
        // stop on its own if nothing is said at all
        silence = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in self?.finish() }
    }

    private func armSilenceTimer() {
        silence?.invalidate()
        silence = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: false) { [weak self] _ in self?.finish() }
    }

    /// Stop listening and hand over what was heard.
    func finish() {
        guard listening else { return }
        listening = false
        silence?.invalidate()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil; request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        levels = Array(repeating: 0, count: levels.count)
        let heard = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let done = onDone; onDone = nil
        done?(heard)
    }

    func speak(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        // Hinglish in Latin letters sounds natural in an Indian English voice; Devanagari gets the Hindi voice
        let devanagari = text.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
        u.voice = AVSpeechSynthesisVoice(language: devanagari ? "hi-IN" : "en-IN")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synth.speak(u)
    }
}
