// The mockup's state: made-up tracks and devices that the panel's buttons change, so the layout can be
// tried on the phone before any of it drives Spotify. Every change comes from a tap, and iOS lets an
// update through after one even with the app in the background.
@preconcurrency import ActivityKit
import Foundation
import os

@available(iOS 17.0, *)
@objc(SGPanelActivity)
public final class SGPanelActivity: NSObject {
    private typealias Track = SGPanelAttributes.Track
    private static let log = Logger(subsystem: "spotifyglass", category: "control panel")
    private static let upNextRows = 3
    private static let timerStep: TimeInterval = 15 * 60
    private static let trackLength: TimeInterval = 167

    private static var queue: [Track] = [
        Track(title: "Blinding Lights", artist: "The Weeknd"),
        Track(title: "Espresso", artist: "Sabrina Carpenter"),
        Track(title: "As It Was", artist: "Harry Styles"),
        Track(title: "Birds of a Feather", artist: "Billie Eilish"),
        Track(title: "Levitating", artist: "Dua Lipa"),
        Track(title: "Good Luck, Babe!", artist: "Chappell Roan"),
        Track(title: "Houdini", artist: "Eminem"),
        Track(title: "Die With A Smile", artist: "Lady Gaga"),
    ]

    private static var state = SGPanelAttributes.ContentState(
        tab: .controls,
        nowPlaying: Track(title: "Numlock", artist: "Protiva"),
        liked: false,
        shuffle: false,
        repeating: false,
        autoplay: true,
        upNext: [],
        queueCount: 0,
        devices: [
            SGPanelAttributes.Device(name: "This iPhone", symbol: "iphone"),
            SGPanelAttributes.Device(name: "MacBook Pro", symbol: "laptopcomputer"),
            SGPanelAttributes.Device(name: "Living room", symbol: "hifispeaker.fill"),
            SGPanelAttributes.Device(name: "Car", symbol: "car.fill"),
        ],
        activeDevice: 0,
        timerEnd: nil
    )

    private static var current: Activity<SGPanelAttributes>? {
        Activity<SGPanelAttributes>.activities.first { $0.activityState == .active || $0.activityState == .stale }
    }

    // Before any start: an intent can launch the app in the background to run.
    @objc public static func listen() {
        NotificationCenter.default.addObserver(forName: SGPanelActionNotification, object: nil, queue: .main) { note in
            guard let action = note.object as? String else { return }
            handle(action)
        }
    }

    // Called when the app comes to the front, the one place ActivityKit lets it request an activity.
    @objc public static func start() {
        guard current == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.notice("[spotifyglass] control panel: activities are off for this app")
            return
        }
        do {
            let activity = try Activity.request(attributes: SGPanelAttributes(), content: content(), pushType: nil)
            log.notice("[spotifyglass] control panel: started \(activity.id, privacy: .public)")
        } catch {
            log.error("[spotifyglass] control panel: request failed: \(String(describing: error), privacy: .public)")
        }
    }

    @objc public static func end() {
        for activity in Activity<SGPanelAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func content() -> ActivityContent<SGPanelAttributes.ContentState> {
        var shown = state
        shown.upNext = Array(queue.prefix(upNextRows))
        shown.queueCount = queue.count
        return ActivityContent(state: shown, staleDate: nil)
    }

    private static func handle(_ action: String) {
        let parts = action.split(separator: ":").map(String.init)
        let value = parts.count > 1 ? parts[1] : ""
        switch parts.first ?? "" {
        case "tab":
            state.tab = Int(value).flatMap(SGPanelAttributes.Tab.init(rawValue:)) ?? .controls
        case "like":
            state.liked.toggle()
        case "shuffle":
            state.shuffle.toggle()
        case "repeat":
            state.repeating.toggle()
        case "autoplay":
            state.autoplay.toggle()
        case "play":
            guard let index = Int(value), queue.indices.contains(index) else { return }
            state.nowPlaying = queue.remove(at: index)
        case "device":
            state.activeDevice = Int(value) ?? 0
        case "timer":
            switch value {
            case "cancel": state.timerEnd = nil
            case "add": state.timerEnd = max(state.timerEnd ?? Date(), Date()).addingTimeInterval(timerStep)
            case "track": state.timerEnd = Date().addingTimeInterval(trackLength)
            default: state.timerEnd = Date().addingTimeInterval((Double(value) ?? 15) * 60)
            }
        default:
            log.notice("[spotifyglass] control panel: unknown action \(action, privacy: .public)")
            return
        }
        log.notice("[spotifyglass] control panel: \(action, privacy: .public)")
        guard let activity = current else { return }
        let next = content()
        Task { await activity.update(next) }
    }
}
