// PushAlarm — AudioService.swift
// Manages ringtone playback via AVAudioPlayer with AVAudioSession set to .playback
// so sound continues even when the mute switch is on.

import AVFoundation
import UIKit

// MARK: - AudioService

final class AudioService: NSObject, ObservableObject {

    static let shared = AudioService()
    private override init() { super.init() }

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentRingtone: RingtoneType? = nil

    private var player: AVAudioPlayer? = nil

    // MARK: - Session Setup

    func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: []         // no duckOthers — alarm must be loud and uninterrupted
            )
            try AVAudioSession.sharedInstance().setActive(true)
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
        guard let url = bundledURL(for: ringtone) else {
            print("[AudioService] Audio file not found: \(ringtone.fileName).\(ringtone.fileExtension)")
            playSystemFallback()
            return
        }
        configureSession()
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
        } catch {
            print("[AudioService] Playback error: \(error)")
            playSystemFallback()
        }
    }

    /// Plays once for preview (not looping).
    func preview(ringtone: RingtoneType) {
        stop()
        guard let url = bundledURL(for: ringtone) else { return }
        configureSession()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = 0
            p.volume = 0.7
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

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentRingtone = nil
        deactivateSession()
    }

    // MARK: - Private Helpers

    private func bundledURL(for ringtone: RingtoneType) -> URL? {
        Bundle.main.url(forResource: ringtone.fileName, withExtension: ringtone.fileExtension)
    }

    /// Falls back to a system sound if the bundle file is missing.
    private func playSystemFallback() {
        AudioServicesPlaySystemSound(1005) // "New Mail" — audible on all iOS versions
        isPlaying = true   // treat as playing so the UI stays consistent
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

// MARK: - AudioServices import shim
import AudioToolbox
