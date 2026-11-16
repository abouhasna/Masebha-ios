import SwiftUI

/// The counter screen (≈ MainActivity2): tap anywhere to count.
struct CounterView: View {
    let dhikrID: Int64

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var model: CounterModel?
    @State private var notFound = false
    @State private var showTimerSheet = false
    @State private var showResetDialog = false
    @State private var powerMode = false
    @State private var showCoachMark = false

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                Color(argb: environment.palette.counterBackground).ignoresSafeArea()
            }
        }
        .onAppear {
            if model == nil {
                model = CounterModel(dhikrID: dhikrID, environment: environment)
                notFound = model == nil
                showCoachMark = !environment.settings.coachMarkSeen
            }
            model?.screenAppeared()
        }
        .onDisappear {
            model?.screenDisappeared()
        }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app pauses the auto-timer (iOS cannot count in the background).
            if phase == .background { model?.screenDisappeared() }
        }
        .alert(tr("counter.missing"), isPresented: $notFound) {
            Button(tr("common.ok"), role: .cancel) { dismiss() }
        }
    }

    @ViewBuilder
    private func content(_ model: CounterModel) -> some View {
        let settings = environment.settings
        let palette = environment.palette
        let toolbarColor = settings.counterToolbarColor(isSupporter: environment.entitlements.isSupporter)
        let iconColor = ColorMath.readableIcon(accent: palette.toolsAccent, on: toolbarColor)

        ZStack {
            ThemedBackground(color: palette.counterBackground, pattern: environment.showsPattern)
            VStack(spacing: 0) {
                CounterBody(model: model, palette: palette, settings: settings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { model.tap() }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("counter.tapArea")
                if !settings.hideNavButtons {
                    navigationButtons(model, color: palette.counterText)
                }
            }
            if powerMode {
                PowerModeOverlay { powerMode = false }
            }
            if showCoachMark {
                CoachMarkOverlay {
                    settings.coachMarkSeen = true
                    showCoachMark = false
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                actionPill(model, iconColor: iconColor)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar(powerMode ? .hidden : .visible, for: .navigationBar)
        .statusBarHidden(powerMode)
        .themedNavigationBar(toolbarColor)
        .tint(Color(argb: iconColor))
        .sheet(isPresented: $showTimerSheet) {
            TimerSheet(initialDelayMs: model.timerDelayMs) { delay in
                model.startTimer(withDelay: delay)
            }
            .appLanguageAndFont(environment)
        }
        .confirmationDialog(tr("counter.reset.message"), isPresented: $showResetDialog, titleVisibility: .visible) {
            Button(tr("common.reset"), role: .destructive) { model.resetSession() }
            Button(tr("counter.reset.all"), role: .destructive) { model.resetAll() }
            Button(tr("common.cancel"), role: .cancel) {}
        }
        .alert(tr("error.title"), isPresented: problemBinding(model)) {
            Button(tr("common.ok"), role: .cancel) {
                if model.problem == .missing { dismiss() }
                model.problem = nil
            }
        } message: {
            Text(model.problem == .missing ? tr("counter.missing") : tr("error.save"))
        }
    }

    private func problemBinding(_ model: CounterModel) -> Binding<Bool> {
        Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })
    }

    // MARK: Toolbar

    private func actionPill(_ model: CounterModel, iconColor: ARGB) -> some View {
        let icon = Color(argb: iconColor)
        let settings = environment.settings
        return HStack(spacing: 0) {
            pillButton(model.isTimerRunning ? "pause.fill" : "play.fill", label: tr("counter.a11y.timer"),
                       id: "counter.timer") { model.toggleTimer() }
                .accessibilityValue(model.isTimerRunning ? "running" : "stopped")
            pillDivider(icon)
            pillButton("moon.fill", label: tr("counter.a11y.power"), id: "counter.power") { powerMode = true }
            pillDivider(icon)
            pillButton("minus", label: tr("counter.a11y.undo"), id: "counter.undo") { model.undo() }
            pillDivider(icon)
            Menu {
                Button(tr("counter.menu.edit_timer"), systemImage: "timer") {
                    model.stopTimer()
                    showTimerSheet = true
                }
                Button(tr("counter.menu.reset"), systemImage: "arrow.counterclockwise") {
                    showResetDialog = true
                }
                Toggle(tr("counter.menu.vibration"), isOn: Bindable(settings).vibrateOnTap)
                Toggle(tr("counter.menu.sound"), isOn: Bindable(settings).tapSound)
                Toggle(tr("counter.menu.today"), isOn: Bindable(settings).showTodayCount)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .rotationEffect(.degrees(90))
                    .frame(width: 40, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(tr("counter.a11y.more"))
            .accessibilityIdentifier("counter.more")
        }
        .foregroundStyle(icon)
        .padding(.horizontal, 4)
        .background(
            Capsule().fill(icon.opacity(0.15))
                .overlay(Capsule().stroke(icon.opacity(0.2), lineWidth: 1))
        )
    }

    private func pillButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func pillDivider(_ color: Color) -> some View {
        Rectangle().fill(color.opacity(0.25)).frame(width: 1, height: 18)
    }

    // MARK: Previous / next

    private func navigationButtons(_ model: CounterModel, color: ARGB) -> some View {
        HStack(spacing: 16) {
            navButton(tr("counter.previous"), color: color, enabled: model.previousID != nil, id: "counter.previous") {
                model.openPrevious()
            }
            navButton(tr("counter.next"), color: color, enabled: model.nextID != nil, id: "counter.next") {
                model.openNext()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private func navButton(_ title: String, color: ARGB, enabled: Bool, id: String,
                           action: @escaping () -> Void) -> some View {
        let tint = Color(argb: color)
        return Button(action: action) {
            Text(title)
                .appFont(15, .medium)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    Capsule().fill(tint.opacity(0.12))
                        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 1))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0)   // keeps its place, like Android's INVISIBLE
        .disabled(!enabled)
        .accessibilityHidden(!enabled)
        .accessibilityIdentifier(id)
    }
}
