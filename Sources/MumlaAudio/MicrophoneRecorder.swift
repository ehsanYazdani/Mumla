@preconcurrency import AVFoundation
#if os(macOS)
import AudioToolbox
import CoreAudio
#endif
import Foundation

public final class MicrophoneRecorder: NSObject, @unchecked Sendable {
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    #if os(macOS)
    private var engine: AVAudioEngine?
    private var engineWriter: EngineFileWriter?
    #endif

    private static var fileSettings: [String: Any] { [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false
    ] }

    public override init() {
        super.init()
    }

    public func microphonePermissionGranted() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Starts recording. On macOS, a connected `inputDeviceUID` is used regardless of the
    /// system default input; otherwise the system default is used.
    public func start(inputDeviceUID: String? = nil) throws -> URL {
        if let recorder, recorder.isRecording {
            throw MicrophoneRecorderError.alreadyRecording
        }
        #if os(macOS)
        if engine != nil {
            throw MicrophoneRecorderError.alreadyRecording
        }
        #endif

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MumlaRecordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("\(UUID().uuidString).wav")
        #if os(macOS)
        if let inputDeviceUID, let deviceID = AudioInputDevices.deviceID(forUID: inputDeviceUID) {
            do {
                try startEngine(deviceID: deviceID, url: url)
                self.outputURL = url
                return url
            } catch {
                // The pinned device couldn't start (busy, just disconnected); use the system default.
            }
        }
        #endif

        let recorder = try AVAudioRecorder(url: url, settings: Self.fileSettings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw MicrophoneRecorderError.failedToStart
        }

        self.recorder = recorder
        self.outputURL = url
        return url
    }

    public func stop() throws -> URL {
        guard let outputURL else {
            throw MicrophoneRecorderError.notRecording
        }
        #if os(macOS)
        stopEngine()
        #endif
        recorder?.stop()
        self.recorder = nil
        self.outputURL = nil
        return outputURL
    }

    public func inputLevel() -> Double {
        #if os(macOS)
        if let engineWriter { return engineWriter.level }
        #endif
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        return min(1, max(0, pow(10, Double(recorder.averagePower(forChannel: 0)) / 30)))
    }

    public func cancel() {
        let url = outputURL
        #if os(macOS)
        stopEngine()
        #endif
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        outputURL = nil

        if let url, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

#if os(macOS)
private extension MicrophoneRecorder {
    func startEngine(deviceID: AudioDeviceID, url: URL) throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        guard let unit = input.audioUnit else { throw MicrophoneRecorderError.failedToStart }
        var device = deviceID
        // Binds only Mumla's input to this device; the system default input stays as it is.
        let status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw MicrophoneRecorderError.failedToStart }

        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let writer = try EngineFileWriter(url: url, inputFormat: inputFormat, settings: Self.fileSettings)
        else { throw MicrophoneRecorderError.failedToStart }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            writer.write(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            writer.finish()
            throw error
        }
        self.engine = engine
        self.engineWriter = writer
    }

    func stopEngine() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engineWriter?.finish()
        self.engine = nil
        self.engineWriter = nil
    }
}

/// Converts tapped device audio to 16 kHz mono and writes it to the recording file.
private final class EngineFileWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let converter: AVAudioConverter
    private let targetFormat: AVAudioFormat
    private var file: AVAudioFile?
    private var currentLevel: Double = 0

    init?(url: URL, inputFormat: AVAudioFormat, settings: [String: Any]) throws {
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        else { return nil }
        converter.downmix = true
        self.converter = converter
        self.targetFormat = targetFormat
        self.file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    }

    var level: Double {
        lock.lock()
        defer { lock.unlock() }
        return currentLevel
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let file else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, output.frameLength > 0, let samples = output.floatChannelData?[0] else { return }
        try? file.write(from: output)

        var sum: Float = 0
        for index in 0..<Int(output.frameLength) { sum += samples[index] * samples[index] }
        let rms = sqrt(sum / Float(output.frameLength))
        let decibels = 20 * log10(max(rms, 1e-7))
        // Same mapping as AVAudioRecorder.averagePower in `inputLevel()`.
        currentLevel = min(1, max(0, pow(10, Double(decibels) / 30)))
    }

    /// Closes the file; later tap callbacks are ignored.
    func finish() {
        lock.lock()
        defer { lock.unlock() }
        file = nil
        currentLevel = 0
    }
}
#endif

public enum MicrophoneRecorderError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case failedToStart

    public var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress."
        case .notRecording:
            return "No recording is in progress."
        case .failedToStart:
            return "Could not start microphone recording."
        }
    }
}
