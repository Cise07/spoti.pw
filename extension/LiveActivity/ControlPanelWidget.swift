// The control panel's face: a tab bar over one of four pages. A tap reaches the tweak as an
// SGPanelIntent, and the new state takes over a second to render, so every on/off control is a Toggle:
// the system flips a toggle's look the moment it is tapped. Views that only change after the render are
// marked invalidatable, so they show as pending meanwhile. Built with the tweak's ControlPanelShared.swift
// by scripts/build-extension.sh.
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let green = Color(red: 0.12, green: 0.84, blue: 0.38)
private let idle = Color.white.opacity(0.08)

@main
struct SGLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        SGControlPanel()
    }
}

extension SGPanelAttributes.Tab {
    var symbol: String {
        switch self {
        case .controls: "slider.horizontal.3"
        case .queue: "list.bullet"
        case .devices: "hifispeaker.2"
        case .timer: "moon.zzz"
        }
    }

    var title: String {
        switch self {
        case .controls: "Controls"
        case .queue: "Queue"
        case .devices: "Devices"
        case .timer: "Timer"
        }
    }
}

struct SGControlPanel: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SGPanelAttributes.self) { context in
            PanelView(state: context.state)
                .padding(12)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(green)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.tab.symbol)
                        .foregroundStyle(green)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Summary(state: context.state)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(green)
            } compactTrailing: {
                if let end = context.state.timerEnd, end > Date() {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .monospacedDigit()
                        .foregroundStyle(green)
                        .frame(maxWidth: 44)
                } else {
                    Image(systemName: context.state.tab.symbol)
                        .foregroundStyle(green)
                }
            } minimal: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(green)
            }
        }
    }
}

private struct Summary: View {
    let state: SGPanelAttributes.ContentState

    var body: some View {
        Group {
            switch state.tab {
            case .controls:
                Text("\(state.nowPlaying.title) · \(state.nowPlaying.artist)")
            case .queue:
                Text(state.upNext.first.map { "Next: \($0.title)" } ?? "The queue is empty")
            case .devices:
                Text("Playing on \(state.devices[state.activeDevice].name)")
            case .timer:
                if let end = state.timerEnd, end > Date() {
                    Text("Music stops in \(Text(timerInterval: Date()...end, countsDown: true))")
                } else {
                    Text("No sleep timer")
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .foregroundStyle(.white)
        .invalidatableContent()
    }
}

private struct PanelView: View {
    let state: SGPanelAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(SGPanelAttributes.Tab.allCases, id: \.self) { tab in
                    Toggle(isOn: tab == state.tab, intent: SGPanelIntent("tab:\(tab.rawValue)")) {
                        EmptyView()
                    }
                    .toggleStyle(TabStyle(tab: tab))
                }
            }
            Group {
                switch state.tab {
                case .controls: ControlsPage(state: state)
                case .queue: QueuePage(state: state)
                case .devices: DevicesPage(state: state)
                case .timer: TimerPage(state: state)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
    }
}

private struct TabStyle: ToggleStyle {
    let tab: SGPanelAttributes.Tab

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tab.symbol)
            if configuration.isOn {
                Text(tab.title)
            }
        }
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity)
        .frame(height: 24)
        .background(Capsule().fill(configuration.isOn ? green.opacity(0.22) : idle))
        .foregroundStyle(configuration.isOn ? green : .white.opacity(0.7))
    }
}

private struct ChipStyle: ToggleStyle {
    let symbol: String
    var onSymbol: String?
    let label: String
    var onLabel: String?

    func makeBody(configuration: Configuration) -> some View {
        let on = configuration.isOn
        VStack(spacing: 3) {
            Image(systemName: on ? onSymbol ?? symbol : symbol)
                .font(.body.weight(.semibold))
            Text(on ? onLabel ?? label : label)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? green.opacity(0.22) : idle))
        .foregroundStyle(on ? green : .white)
    }
}

private struct ChipButton: View {
    let action: String
    let symbol: String
    let label: String

    var body: some View {
        Button(intent: SGPanelIntent(action)) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                Text(label)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(idle))
        }
        .buttonStyle(.plain)
    }
}

private struct ControlsPage: View {
    let state: SGPanelAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(state.nowPlaying.title)
                    .font(.subheadline.weight(.semibold))
                Text(state.nowPlaying.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .lineLimit(1)
            .invalidatableContent()
            HStack(spacing: 8) {
                Toggle(isOn: state.liked, intent: SGPanelIntent("like")) { EmptyView() }
                    .toggleStyle(ChipStyle(symbol: "heart", onSymbol: "heart.fill", label: "Save", onLabel: "Saved"))
                Toggle(isOn: state.shuffle, intent: SGPanelIntent("shuffle")) { EmptyView() }
                    .toggleStyle(ChipStyle(symbol: "shuffle", label: "Shuffle"))
                Toggle(isOn: state.repeating, intent: SGPanelIntent("repeat")) { EmptyView() }
                    .toggleStyle(ChipStyle(symbol: "repeat", label: "Repeat"))
                Toggle(isOn: state.autoplay, intent: SGPanelIntent("autoplay")) { EmptyView() }
                    .toggleStyle(ChipStyle(symbol: "infinity", label: "Autoplay"))
            }
        }
    }
}

private struct QueuePage: View {
    let state: SGPanelAttributes.ContentState

    var body: some View {
        VStack(spacing: 4) {
            if state.upNext.isEmpty {
                Text("The queue is empty")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 74)
            }
            ForEach(Array(state.upNext.enumerated()), id: \.offset) { index, track in
                Button(intent: SGPanelIntent("play:\(index)")) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(green)
                        Text(track.title)
                            .font(.footnote.weight(.semibold))
                        Text(track.artist)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer(minLength: 0)
                    }
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(idle))
                }
                .buttonStyle(.plain)
            }
            if state.queueCount > state.upNext.count {
                Text("and \(state.queueCount - state.upNext.count) more")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .invalidatableContent()
    }
}

private struct DevicesPage: View {
    let state: SGPanelAttributes.ContentState

    var body: some View {
        VStack(spacing: 6) {
            ForEach([0, 2], id: \.self) { first in
                HStack(spacing: 6) {
                    ForEach(first..<min(first + 2, state.devices.count), id: \.self) { index in
                        Toggle(isOn: index == state.activeDevice, intent: SGPanelIntent("device:\(index)")) { EmptyView() }
                            .toggleStyle(DeviceStyle(device: state.devices[index]))
                    }
                }
            }
        }
    }
}

private struct DeviceStyle: ToggleStyle {
    let device: SGPanelAttributes.Device

    func makeBody(configuration: Configuration) -> some View {
        let on = configuration.isOn
        HStack(spacing: 8) {
            Image(systemName: device.symbol)
                .frame(width: 20)
            Text(device.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            if on {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? green.opacity(0.22) : idle))
        .foregroundStyle(on ? green : .white)
    }
}

private struct TimerPage: View {
    let state: SGPanelAttributes.ContentState

    var body: some View {
        Group {
            if let end = state.timerEnd, end > Date() {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Music stops in")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                        Text(timerInterval: Date()...end, countsDown: true)
                            .font(.system(size: 34, weight: .bold).monospacedDigit())
                            .foregroundStyle(green)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        ChipButton(action: "timer:add", symbol: "plus", label: "15 min")
                        ChipButton(action: "timer:cancel", symbol: "xmark", label: "Cancel")
                    }
                    .frame(width: 140)
                }
            } else {
                HStack(spacing: 8) {
                    ChipButton(action: "timer:15", symbol: "moon", label: "15 min")
                    ChipButton(action: "timer:30", symbol: "moon", label: "30 min")
                    ChipButton(action: "timer:60", symbol: "moon", label: "1 hour")
                    ChipButton(action: "timer:track", symbol: "music.note", label: "End of track")
                }
            }
        }
        .invalidatableContent()
    }
}
