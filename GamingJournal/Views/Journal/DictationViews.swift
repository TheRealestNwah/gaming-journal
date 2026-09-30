import AVFoundation
import Observation
import Speech
import SwiftUI

/// Listens through the microphone and transcribes on the device when it can. Words arrive in
/// `transcript` as they're recognised; `stop()` ends the take.
@MainActor
@Observable
final class Dictation {
    enum State: Equatable {
        case idle, listening
        case unavailable(String)
    }

    private(set) var state = State.idle
    private(set) var transcript = ""

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private let recognizer = SFSpeechRecognizer()

    var isListening: Bool { state == .listening }

    func start() async {
        guard !isListening else { return }
        transcript = ""
        guard await Self.speechAllowed(), await AVAudioApplication.requestRecordPermission() else {
            state = .unavailable("Allow the microphone and speech recognition for Hearthbound in the Settings app to dictate.")
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            state = .unavailable("Dictation isn't available right now.")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Keep the words on the phone whenever the device can.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request.addsPunctuation = true
            self.request = request

            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            state = .listening

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let finished = error != nil || (result?.isFinal ?? false)
                Task { @MainActor in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if finished { self.stop() }
                }
            }
        } catch {
            stop()
            state = .unavailable("Couldn't start listening.")
        }
    }

    /// Ends the take and returns what was heard.
    @discardableResult
    func stop() -> String {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if state == .listening { state = .idle }
        return transcript
    }

    private static func speechAllowed() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

/// A mic button below the page. While listening it shows the words as they come; stopping
/// adds them to the entry.
struct DictationRow: View {
    @Binding var text: String
    @State private var dictation = Dictation()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    if dictation.isListening {
                        text = DictationText.append(dictation.stop(), to: text)
                    } else {
                        Task { await dictation.start() }
                    }
                } label: {
                    Label(dictation.isListening ? "Stop dictating" : "Dictate",
                          systemImage: dictation.isListening ? "stop.circle.fill" : "mic.fill")
                        .font(Theme.pageControl)
                        .foregroundStyle(Theme.rubric)
                }
                .buttonStyle(.borderless)
                if dictation.isListening {
                    Circle()
                        .fill(Theme.rubric)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text("Listening…")
                        .font(.caption)
                        .foregroundStyle(Theme.fadedInk)
                }
            }
            if dictation.isListening && !dictation.transcript.isEmpty {
                Text(dictation.transcript)
                    .font(Theme.bookItalic(17))
                    .foregroundStyle(Theme.fadedInk)
                    .accessibilityLabel("Heard so far: \(dictation.transcript)")
            }
            if case .unavailable(let reason) = dictation.state {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Theme.fadedInk)
            }
        }
        // Leaving the editor mid-take keeps what was said.
        .onDisappear {
            if dictation.isListening {
                text = DictationText.append(dictation.stop(), to: text)
            }
        }
    }
}
