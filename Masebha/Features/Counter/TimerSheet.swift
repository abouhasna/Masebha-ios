import SwiftUI

/// The auto-timer dialog (≈ timer_dialog.xml): set the interval by hand, or by tapping 4 times
/// at your own pace. "Start" saves the interval for this dhikr and starts counting.
/// "Cancel" discards the change (on Android a cancelled change was kept by mistake).
struct TimerSheet: View {
    let onStart: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .manual
    @State private var delayMs: Int
    @State private var tapTimes: [TimeInterval] = []
    @State private var calculated = false

    enum Mode: Hashable {
        case manual, auto
    }

    init(initialDelayMs: Int, onStart: @escaping (Int) -> Void) {
        self.onStart = onStart
        _delayMs = State(initialValue: max(TimerDelay.minimumMs, initialDelayMs))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Text(tr("timer.message"))
                    .appFont(17, .regular)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Picker(tr("timer.title"), selection: $mode) {
                    Text(tr("timer.manual")).tag(Mode.manual)
                    Text(tr("timer.auto")).tag(Mode.auto)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("timer.mode")

                if mode == .manual {
                    manual
                } else {
                    auto
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(tr("timer.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("common.cancel")) { dismiss() }
                        .accessibilityIdentifier("timer.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("common.start")) {
                        onStart(delayMs)
                        dismiss()
                    }
                    .bold()
                    .accessibilityIdentifier("timer.start")
                }
            }
        }
        .tint(Color(argb: SettingsStyle.accent))
        .presentationDetents([.medium, .large])
    }

    private var manual: some View {
        VStack(spacing: 6) {
            HStack(spacing: 18) {
                stepButton("minus", size: 30, label: tr("timer.a11y.minus_second"), id: "timer.minusSecond") {
                    delayMs = TimerDelay.minusSecond(delayMs)
                }
                stepButton("minus", size: 18, label: tr("timer.a11y.minus_tenth"), id: "timer.minusTenth") {
                    delayMs = TimerDelay.minusTenth(delayMs)
                }
                Text(TimerDelay.display(delayMs))
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 110)
                    .accessibilityIdentifier("timer.value")
                stepButton("plus", size: 18, label: tr("timer.a11y.plus_tenth"), id: "timer.plusTenth") {
                    delayMs = TimerDelay.plusTenth(delayMs)
                }
                stepButton("plus", size: 30, label: tr("timer.a11y.plus_second"), id: "timer.plusSecond") {
                    delayMs = TimerDelay.plusSecond(delayMs)
                }
            }
            .environment(\.layoutDirection, .leftToRight)   // numbers read left to right in both languages
            Text(tr("timer.unit"))
                .appFont(15, .regular)
                .foregroundStyle(.secondary)
        }
    }

    private var auto: some View {
        VStack(spacing: 16) {
            Text(calculated ? tr("timer.calc_done") : tr("timer.auto.instruction"))
                .appFont(17, .regular)
                .multilineTextAlignment(.center)
            Button {
                recordTap()
            } label: {
                Text(tr("timer.tap_here"))
                    .appFont(22, .medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 110)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(argb: SettingsStyle.accent)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timer.tapHere")
            if calculated {
                Text(tr("timer.set_format", Double(delayMs) / 1000))
                    .appFont(16, .medium)
                    .accessibilityIdentifier("timer.autoResult")
            }
        }
    }

    private func recordTap() {
        tapTimes.append(ProcessInfo.processInfo.systemUptime)
        if let average = TimerDelay.averageInterval(tapTimes: tapTimes) {
            delayMs = average
            calculated = true
            tapTimes.removeAll()  // the next 4 taps measure again
        }
    }

    private func stepButton(_ symbol: String, size: CGFloat, label: String, id: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}
