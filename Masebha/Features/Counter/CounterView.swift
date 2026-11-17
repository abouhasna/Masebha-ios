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
                    PreviousNextBar(color: palette.counterText, previousEnabled: model.previousID != nil,
                                    nextEnabled: model.nextID != nil, onPrevious: { model.openPrevious() },
                                    onNext: { model.openNext() })
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
        return ActionPill(color: icon) {
            PillButton(symbol: model.isTimerRunning ? "pause.fill" : "play.fill", label: tr("counter.a11y.timer"),
                       id: "counter.timer") { model.toggleTimer() }
                .accessibilityValue(model.isTimerRunning ? "running" : "stopped")
            PillDivider(color: icon)
            PillButton(symbol: "moon.fill", label: tr("counter.a11y.power"), id: "counter.power") { powerMode = true }
            PillDivider(color: icon)
            PillButton(symbol: "minus", label: tr("counter.a11y.undo"), id: "counter.undo") { model.undo() }
            PillDivider(color: icon)
            Menu {
                Button(tr("counter.menu.edit_timer"), systemImage: "timer") {
                    model.stopTimer()
                    showTimerSheet = true
                }
                Button(tr("counter.menu.reset"), systemImage: "arrow.counterclockwise") {
                    showResetDialog = true
                }
                // On/off items: iOS shows a ✓ when on.
                Toggle(isOn: Bindable(settings).vibrateOnTap) {
                    Label(tr("counter.menu.vibration"), systemImage: "iphone.radiowaves.left.and.right")
                }
                Toggle(isOn: Bindable(settings).tapSound) {
                    Label(tr("counter.menu.sound"), systemImage: "speaker.wave.2")
                }
                Toggle(isOn: Bindable(settings).showTodayCount) {
                    Label(tr("counter.menu.today"), systemImage: "calendar")
                }
            } label: {
                PillMoreLabel()
            }
            .accessibilityLabel(tr("counter.a11y.more"))
            .accessibilityIdentifier("counter.more")
        }
    }
}
