// Compiled into both the tweak and extension/LiveActivity: ActivityKit pairs the two sides by the
// attributes' type name and App Intents by the intent's, so this must stay identical in both.
import ActivityKit
import AppIntents
import Foundation

@available(iOS 16.1, *)
struct SGPanelAttributes: ActivityAttributes {
    enum Tab: Int, Codable, Hashable, CaseIterable {
        case controls, queue, devices, timer
    }

    struct Track: Codable, Hashable {
        var title: String
        var artist: String
    }

    struct Device: Codable, Hashable {
        var name: String
        var symbol: String
    }

    struct ContentState: Codable, Hashable {
        var tab: Tab
        var nowPlaying: Track
        var liked: Bool
        var shuffle: Bool
        var repeating: Bool
        var autoplay: Bool
        var upNext: [Track]   // the first rows of the queue
        var queueCount: Int
        var devices: [Device]
        var activeDevice: Int
        var timerEnd: Date?
    }
}

let SGPanelActionNotification = Notification.Name("SGPanelAction")

// A LiveActivityIntent runs in the app's process, where the tweak turns the action into a new state.
@available(iOS 17.0, *)
struct SGPanelIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Control panel action"
    static let isDiscoverable = false

    @Parameter(title: "Action")
    var action: String

    init() {}

    init(_ action: String) {
        self.action = action
    }

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: SGPanelActionNotification, object: action)
        return .result()
    }
}
