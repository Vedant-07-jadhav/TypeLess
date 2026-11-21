import Foundation
import AVFoundation

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    static let shared = AudioRecorder()

    private var recorder: AVAudioRecorder?
    private var recordingStartTime: Date?
    private var meterTimer: Timer?
    private var speechDetected: Bool = false
    private var lastSpeechTime: Date?
    private(set) var currentAudioURL: URL?

    var onSilenceDetected: (() -> Void)?
    var onAudioLevel: ((Float) -> Void)?

    var isRecording: Bool {
        return recorder?.isRecording ?? false
    }

    var recordingDuration: TimeInterval {
        guard let start = recordingStartTime, isRecording else { return 0 }
        return Date().timeIntervalSince(start)
    }

    static func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    func startRecording() -> (success: Bool, error: String?) {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if authStatus == .denied || authStatus == .restricted {
            return (false, "Microphone access denied. Please allow microphone access in System Settings > Privacy & Security > Microphone.")
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "wisperflow_rec_\(Int(Date().timeIntervalSince1970)).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        currentAudioURL = fileURL

        // Clean up any old recording file
        try? FileManager.default.removeItem(at: fileURL)

        // 16kHz Mono AAC - Whisper optimal format with minimal payload size
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 32000
        ]

        do {
            recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            guard let recorder = recorder, recorder.record() else {
                return (false, "Failed to start audio recording.")
            }
            recordingStartTime = Date()
            speechDetected = false
            lastSpeechTime = nil

            startMetering()

            return (true, nil)
        } catch {
            return (false, "Audio recording error: \(error.localizedDescription)")
        }
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let rec = self.recorder, rec.isRecording else { return }
            rec.updateMeters()
            let power = rec.averagePower(forChannel: 0) // -160 to 0 dB
            let peak = rec.peakPower(forChannel: 0)

            // Normalized level 0.0 to 1.0 for visual meter
            let normalized = max(0.0, min(1.0, (power + 50.0) / 50.0))
            self.onAudioLevel?(normalized)

            guard AppConfig.shared.autoStopOnSilence else { return }

            // Speech threshold: normal talking into Mac mic is -34 dB or louder
            let isSpeaking = power > -36.0 || peak > -30.0

            if isSpeaking {
                self.speechDetected = true
                self.lastSpeechTime = Date()
            } else if self.speechDetected {
                if let lastSpoke = self.lastSpeechTime {
                    let silenceDuration = Date().timeIntervalSince(lastSpoke)
                    let totalDuration = self.recordingDuration

                    // Stop after 1.4 seconds of silence (and at least 0.8s total speech)
                    if silenceDuration >= 1.4 && totalDuration >= 0.8 {
                        self.stopMetering()
                        DispatchQueue.main.async {
                            self.onSilenceDetected?()
                        }
                    }
                }
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    func stopRecording() -> (url: URL?, duration: TimeInterval, error: String?) {
        stopMetering()
        guard let rec = recorder, isRecording else {
            return (nil, 0, "No active recording")
        }

        let duration = recordingDuration
        rec.stop()
        recorder = nil
        recordingStartTime = nil

        guard let url = currentAudioURL, FileManager.default.fileExists(atPath: url.path) else {
            return (nil, duration, "Recording file was not found")
        }

        // Check file size
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attrs[.size] as? Int64 ?? 0
            if fileSize < 500 || duration < 0.3 {
                try? FileManager.default.removeItem(at: url)
                return (nil, duration, "Audio was too short or empty.")
            }
        } catch {
            return (nil, duration, "Error checking recording file: \(error.localizedDescription)")
        }

        return (url, duration, nil)
    }

    func cancelRecording() {
        stopMetering()
        if let rec = recorder, isRecording {
            rec.stop()
        }
        recorder = nil
        recordingStartTime = nil
        if let url = currentAudioURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentAudioURL = nil
    }
}
