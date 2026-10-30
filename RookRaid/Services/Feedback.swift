import Foundation
import UIKit
import CoreHaptics
import AVFoundation

// MARK: - Haptik

enum HapticKind {
    case select, move, capture, heavyCapture, cardCast, frost, lightning, shield, trap, summon, check, victory, defeat, invalid, mana, tick
    // Truhen: Landung, drei Lade-Taps (immer stärker), Aufwerten, Aufplatzen, Belohnungen
    case chestLand, chestCharge1, chestCharge2, chestCharge3, chestUpgrade, chestBurst, chestCount, chestReveal, chestBigReveal
    // Truhen-Öffnung, zweite Generation: Grollen vor dem Aufplatzen, Karte fliegt heraus, Herzklopfen, Umdrehen, Splitter-Regen
    case chestRumble, cardWhoosh, cardAnticipate, cardFlip, shardShower
}

@MainActor
final class Haptics {
    static let shared = Haptics()

    var enabled = true
    private var engine: CHHapticEngine?
    private let supportsCH = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private let selection = UISelectionFeedbackGenerator()
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        prepareEngine()
    }

    private func prepareEngine() {
        guard supportsCH else { return }
        do {
            let e = try CHHapticEngine()
            e.playsHapticsOnly = true
            e.isAutoShutdownEnabled = true
            e.resetHandler = {
                Task { @MainActor in Haptics.shared.restartEngine() }
            }
            try e.start()
            engine = e
        } catch {
            engine = nil
        }
    }

    func restartEngine() {
        try? engine?.start()
    }

    func play(_ kind: HapticKind) {
        guard enabled else { return }
        switch kind {
        case .select: selection.selectionChanged()
        case .tick: light.impactOccurred(intensity: 0.5)
        case .move: medium.impactOccurred(intensity: 0.7)
        case .invalid: notification.notificationOccurred(.error)
        case .check: notification.notificationOccurred(.warning)
        case .mana: light.impactOccurred(intensity: 0.4)
        default:
            if !playPattern(kind) { fallback(kind) }
        }
    }

    private func fallback(_ kind: HapticKind) {
        switch kind {
        case .capture, .trap: heavy.impactOccurred()
        case .heavyCapture, .lightning: heavy.impactOccurred(intensity: 1.0)
        case .victory: notification.notificationOccurred(.success)
        case .defeat: notification.notificationOccurred(.error)
        case .frost, .shield, .summon: rigid.impactOccurred()
        case .chestLand, .chestBurst: heavy.impactOccurred(intensity: 1.0)
        case .chestCharge1: medium.impactOccurred(intensity: 0.6)
        case .chestCharge2: medium.impactOccurred(intensity: 0.85)
        case .chestCharge3: heavy.impactOccurred(intensity: 1.0)
        case .chestUpgrade, .chestBigReveal: notification.notificationOccurred(.success)
        case .chestCount, .shardShower: light.impactOccurred(intensity: 0.45)
        case .chestRumble, .cardAnticipate: medium.impactOccurred(intensity: 0.8)
        case .cardWhoosh: light.impactOccurred(intensity: 0.5)
        case .cardFlip: heavy.impactOccurred(intensity: 1.0)
        default: medium.impactOccurred()
        }
    }

    private func transient(_ t: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: t)
    }

    private func continuous(_ t: TimeInterval, _ duration: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: t, duration: duration)
    }

    private func events(for kind: HapticKind) -> ([CHHapticEvent], [CHHapticParameterCurve]) {
        switch kind {
        case .capture:
            return ([transient(0, 1.0, 0.8), continuous(0.02, 0.12, 0.55, 0.2)], [])
        case .heavyCapture:
            return ([transient(0, 1.0, 1.0), transient(0.07, 0.8, 0.4), continuous(0.05, 0.25, 0.7, 0.1)], [])
        case .cardCast:
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 0.2),
                .init(relativeTime: 0.25, value: 1.0),
                .init(relativeTime: 0.32, value: 0.0)
            ], relativeTime: 0)
            return ([continuous(0, 0.32, 0.8, 0.5), transient(0.3, 0.9, 0.9)], [curve])
        case .frost:
            return ([transient(0, 0.5, 1.0), transient(0.05, 0.4, 1.0), transient(0.1, 0.6, 1.0),
                     transient(0.16, 0.35, 1.0), transient(0.22, 0.5, 1.0)], [])
        case .lightning:
            return ([transient(0, 1.0, 1.0), transient(0.06, 0.9, 1.0), continuous(0.08, 0.35, 0.9, 0.05)], [])
        case .shield:
            return ([transient(0, 0.6, 0.3), continuous(0.02, 0.2, 0.35, 0.3)], [])
        case .trap:
            return ([transient(0, 1.0, 0.6), transient(0.1, 0.7, 0.9)], [])
        case .summon:
            return ([continuous(0, 0.18, 0.6, 0.1), transient(0.18, 0.8, 0.5)], [])
        case .victory:
            return ([transient(0, 0.7, 0.5), transient(0.12, 0.8, 0.6), transient(0.24, 1.0, 0.8),
                     continuous(0.3, 0.45, 0.6, 0.3)], [])
        case .defeat:
            return ([continuous(0, 0.5, 0.6, 0.05), transient(0.5, 0.6, 0.1)], [])
        case .chestLand:
            // Dumpfer Aufprall, kurzes Nachbeben
            return ([transient(0, 1.0, 0.15), continuous(0.02, 0.22, 0.55, 0.05), transient(0.16, 0.45, 0.2)], [])
        case .chestCharge1:
            return ([transient(0, 0.55, 0.45), continuous(0.01, 0.08, 0.35, 0.2)], [])
        case .chestCharge2:
            return ([transient(0, 0.78, 0.6), continuous(0.01, 0.12, 0.5, 0.3), transient(0.1, 0.4, 0.8)], [])
        case .chestCharge3:
            // Die Truhe bebt: Grollen steigt an, dann ein harter Schlag
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 0.3),
                .init(relativeTime: 0.22, value: 1.0),
                .init(relativeTime: 0.3, value: 0.6)
            ], relativeTime: 0)
            return ([transient(0, 1.0, 0.75), continuous(0.02, 0.3, 0.8, 0.25), transient(0.28, 0.9, 0.9)], [curve])
        case .chestUpgrade:
            // Aufwerten: Doppelschlag, Anschwellen, heller Abschluss
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 0.2),
                .init(relativeTime: 0.35, value: 1.0),
                .init(relativeTime: 0.5, value: 0.0)
            ], relativeTime: 0.1)
            return ([transient(0, 1.0, 1.0), transient(0.07, 0.9, 0.7), continuous(0.1, 0.5, 0.9, 0.5),
                     transient(0.62, 1.0, 1.0), transient(0.72, 0.6, 1.0)], [curve])
        case .chestBurst:
            // Aufplatzen: drei harte Schläge, dann ausklingendes Grollen
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 1.0),
                .init(relativeTime: 0.8, value: 0.0)
            ], relativeTime: 0.18)
            return ([transient(0, 1.0, 0.3), transient(0.07, 1.0, 0.6), transient(0.14, 1.0, 1.0),
                     continuous(0.18, 0.8, 1.0, 0.1)], [curve])
        case .chestCount:
            return ([transient(0, 0.4, 0.9)], [])
        case .chestReveal:
            return ([transient(0, 0.7, 0.5), continuous(0.02, 0.1, 0.4, 0.4)], [])
        case .chestBigReveal:
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 0.4),
                .init(relativeTime: 0.3, value: 1.0),
                .init(relativeTime: 0.6, value: 0.0)
            ], relativeTime: 0.05)
            return ([transient(0, 1.0, 1.0), continuous(0.05, 0.6, 0.8, 0.6), transient(0.7, 1.0, 0.7),
                     transient(0.82, 0.7, 1.0), transient(0.94, 0.5, 1.0)], [curve])
        case .chestRumble:
            // Die Truhe zittert: Grollen schwillt an, Rattern wird immer dichter und härter
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 0.25),
                .init(relativeTime: 0.45, value: 1.0)
            ], relativeTime: 0)
            var evts: [CHHapticEvent] = [continuous(0, 0.5, 0.9, 0.25)]
            var tt: TimeInterval = 0.02
            var i = 0
            while tt < 0.48 {
                evts.append(transient(tt, Float(0.3 + 0.6 * tt / 0.48), Float(0.4 + 0.5 * tt / 0.48)))
                tt += max(0.035, 0.08 - Double(i) * 0.006)
                i += 1
            }
            return (evts, [curve])
        case .cardWhoosh:
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 0.0),
                .init(relativeTime: 0.22, value: 0.7),
                .init(relativeTime: 0.45, value: 0.0)
            ], relativeTime: 0)
            return ([continuous(0, 0.45, 0.6, 0.85), transient(0.42, 0.55, 0.6)], [curve])
        case .cardAnticipate:
            // Herzklopfen, immer schneller und stärker
            return ([transient(0, 0.45, 0.25), transient(0.13, 0.3, 0.2),
                     transient(0.42, 0.6, 0.3), transient(0.53, 0.42, 0.25),
                     transient(0.76, 0.8, 0.35), transient(0.85, 0.6, 0.3),
                     continuous(0.0, 1.0, 0.25, 0.1)], [])
        case .cardFlip:
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 1.0),
                .init(relativeTime: 0.5, value: 0.0)
            ], relativeTime: 0.04)
            return ([transient(0, 1.0, 1.0), transient(0.05, 0.8, 0.6), continuous(0.04, 0.5, 0.7, 0.8),
                     transient(0.3, 0.6, 1.0), transient(0.42, 0.45, 1.0), transient(0.54, 0.3, 1.0)], [curve])
        case .shardShower:
            let times: [TimeInterval] = [0, 0.04, 0.09, 0.12, 0.17, 0.21, 0.26, 0.3, 0.36, 0.41, 0.47, 0.53]
            return (times.enumerated().map { i, tt in transient(tt, Float(0.35 + 0.25 * Double(i % 3) / 2), 1.0) }, [])
        default:
            return ([transient(0, 0.7, 0.5)], [])
        }
    }

    private func playPattern(_ kind: HapticKind) -> Bool {
        guard let engine else { return false }
        do {
            let (evts, curves) = events(for: kind)
            let pattern = try CHHapticPattern(events: evts, parameterCurves: curves)
            try engine.start()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Sound

enum SoundKind: String, CaseIterable {
    case move, capture, card, frost, lightning, shield, check, castle, trap, summon, victory, defeat, select, notify
    // Truhen
    case chestLand = "chest_land", chestTap = "chest_tap", chestUpgrade = "chest_upgrade", chestOpen = "chest_open"
    case reward, rewardBig = "reward_big"
    case chestRumble = "chest_rumble", cardWhoosh = "card_whoosh", cardFlip = "card_flip", shardShower = "shard_shower"
}

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    var enabled = true
    private var players: [SoundKind: [AVAudioPlayer]] = [:]
    private var nextIndex: [SoundKind: Int] = [:]

    private init() {
        // .ambient respektiert den Stummschalter des iPhones und mischt sich mit Musik.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for kind in SoundKind.allCases {
            guard let url = Bundle.main.url(forResource: kind.rawValue, withExtension: "wav") else { continue }
            var list: [AVAudioPlayer] = []
            for _ in 0..<3 {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay()
                    list.append(p)
                }
            }
            players[kind] = list
        }
    }

    func play(_ kind: SoundKind, volume: Float = 1.0) {
        guard enabled, let list = players[kind], !list.isEmpty else { return }
        let i = nextIndex[kind, default: 0] % list.count
        nextIndex[kind] = i + 1
        let p = list[i]
        p.volume = volume
        p.currentTime = 0
        p.play()
    }
}

/// Bündelt Sound und Haptik, damit jedes Ereignis beides auslöst.
@MainActor
enum Feedback {
    static func apply(settings: Settings) {
        Haptics.shared.enabled = settings.haptics
        SoundPlayer.shared.enabled = settings.sound
    }

    static func play(_ sound: SoundKind?, _ haptic: HapticKind?) {
        if let sound { SoundPlayer.shared.play(sound) }
        if let haptic { Haptics.shared.play(haptic) }
    }
}
