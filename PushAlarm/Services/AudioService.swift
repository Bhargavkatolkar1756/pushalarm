// PushAlarm — AudioService.swift
// Manages ringtone playback via AVAudioPlayer with AVAudioSession set to .playback
// so sound continues even when the mute switch is on.

import AVFoundation
import AudioToolbox
import UIKit

// MARK: - AudioService

final class AudioService: NSObject, ObservableObject {

    static let shared = AudioService()
    private override init() { super.init() }

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentRingtone: RingtoneType? = nil

    private var player: AVAudioPlayer? = nil
    private var repeatingTimer: Timer? = nil

    // MARK: - Session Setup

    func configureSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.duckOthers]
            )
            try session.setActive(true)
        } catch {
            print("[AudioService] Session config error: \(error)")
        }
    }

    func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Playback

    /// Starts looping playback of the given ringtone. Configures the audio session first.
    func play(ringtone: RingtoneType) {
        stop()
        configureSession()

        // Use bundled file if available, or generate a high-urgency continuous alarm audio file
        let url = bundledURL(for: ringtone) ?? generatedWavURL(for: ringtone)

        if let url = url {
            do {
                let p = try AVAudioPlayer(contentsOf: url)
                p.numberOfLoops = -1   // loop indefinitely
                p.volume = 1.0
                p.delegate = self
                p.prepareToPlay()
                p.play()
                player = p
                isPlaying = true
                currentRingtone = ringtone

                // Boost screen brightness during alarm
                DispatchQueue.main.async {
                    UIScreen.main.brightness = 1.0
                }
                return
            } catch {
                print("[AudioService] Playback error: \(error)")
            }
        }

        // System fallback looping timer if file creation fails
        startSystemSoundLoop()
    }

    /// Plays once for preview (not looping).
    func preview(ringtone: RingtoneType) {
        stop()
        configureSession()

        let url = bundledURL(for: ringtone) ?? generatedWavURL(for: ringtone)
        if let url = url {
            do {
                let p = try AVAudioPlayer(contentsOf: url)
                p.numberOfLoops = 0
                p.volume = 0.8
                p.delegate = self
                p.prepareToPlay()
                p.play()
                player = p
                isPlaying = true
                currentRingtone = ringtone
            } catch {
                print("[AudioService] Preview error: \(error)")
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        repeatingTimer?.invalidate()
        repeatingTimer = nil
        isPlaying = false
        currentRingtone = nil
        deactivateSession()
    }

    // MARK: - Private Helpers

    private func bundledURL(for ringtone: RingtoneType) -> URL? {
        Bundle.main.url(forResource: ringtone.fileName, withExtension: ringtone.fileExtension)
    }

    private func startSystemSoundLoop() {
        isPlaying = true
        repeatingTimer?.invalidate()
        AudioServicesPlaySystemSound(1005)
        repeatingTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            AudioServicesPlaySystemSound(1005)
        }
    }

    // MARK: - Audio Waveform Generator for Alarms

    /// Generates a loud 2-second WAV audio file in temporary directory for immediate alarm playback.
    private func generatedWavURL(for ringtone: RingtoneType) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("alarm_\(ringtone.rawValue).wav")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        let sampleRate: Double = 44100.0
        let duration: Double = 2.0
        let numSamples = Int(sampleRate * duration)

        var pcmData = Data()
        pcmData.reserveCapacity(numSamples * 2)

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            var sampleValue: Double = 0.0

            switch ringtone {
            case .siren:
                // Alternating siren sweep 440Hz <-> 880Hz
                let freq = 440.0 + 440.0 * (sin(2.0 * .pi * 2.0 * t) * 0.5 + 0.5)
                sampleValue = sin(2.0 * .pi * freq * t)

            case .airHorn:
                // Low brass square wave 250Hz + harmonics
                let val = sin(2.0 * .pi * 250.0 * t)
                sampleValue = val > 0 ? 0.8 : -0.8

            case .drillSergeant:
                // Pulsing 600Hz alert
                let pulse = (sin(2.0 * .pi * 5.0 * t) > 0) ? 1.0 : 0.0
                sampleValue = sin(2.0 * .pi * 600.0 * t) * pulse

            case .foghorn:
                // Low deep rumble 150Hz
                sampleValue = sin(2.0 * .pi * 150.0 * t) * 0.9

            case .emergencyBeacon:
                // High double beep 1000Hz
                let pulse = (fmod(t, 0.5) < 0.25) ? 1.0 : 0.0
                sampleValue = sin(2.0 * .pi * 1000.0 * t) * pulse
            }

            let int16Sample = Int16(max(-1.0, min(1.0, sampleValue)) * 32767.0)
            withUnsafeBytes(of: int16Sample.littleEndian) { pcmData.append(contentsOf: $0) }
        }

        // Write 44-byte WAV header
        var header = Data()
        let dataSize = UInt32(pcmData.count)
        let fileSize = UInt32(36 + dataSize)
        let sampleRateU = UInt32(sampleRate)
        let byteRate = UInt32(sampleRate * 2)

        header.append(contentsOf: "RIFF".utf8)
        withUnsafeBytes(of: fileSize.littleEndian) { header.append(contentsOf: $0) }
        header.append(contentsOf: "WAVEfmt ".utf8)
        withUnsafeBytes(of: UInt32(16).littleEndian) { header.append(contentsOf: $0) } // Subchunk1Size (16 for PCM)
        withUnsafeBytes(of: UInt16(1).littleEndian) { header.append(contentsOf: $0) }  // AudioFormat (1 for PCM)
        withUnsafeBytes(of: UInt16(1).littleEndian) { header.append(contentsOf: $0) }  // NumChannels (1 mono)
        withUnsafeBytes(of: sampleRateU.littleEndian) { header.append(contentsOf: $0) }
        withUnsafeBytes(of: byteRate.littleEndian) { header.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(2).littleEndian) { header.append(contentsOf: $0) }  // BlockAlign (2 bytes)
        withUnsafeBytes(of: UInt16(16).littleEndian) { header.append(contentsOf: $0) } // BitsPerSample (16 bit)
        header.append(contentsOf: "data".utf8)
        withUnsafeBytes(of: dataSize.littleEndian) { header.append(contentsOf: $0) }

        var wavFile = Data()
        wavFile.append(header)
        wavFile.append(pcmData)

        do {
            try wavFile.write(to: fileURL)
            return fileURL
        } catch {
            print("[AudioService] Failed to write WAV file: \(error)")
            return nil
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.currentRingtone = nil
        }
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[AudioService] Decode error: \(String(describing: error))")
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
        }
    }
}
