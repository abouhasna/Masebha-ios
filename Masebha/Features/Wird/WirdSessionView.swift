import SwiftUI
import UIKit

/// Going through a wird (≈ WirdSessionActivity): tap anywhere to count the zikr on screen; when
/// it reaches its target the screen moves to the next pending one. Skip finishes a zikr without
/// its target. When nothing is pending, "Wird completed" shows and the screen closes.
struct WirdSessionView: View {
    let wirdID: Int64

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFontFamily) private var family
    @State private var model: WirdSessionModel?
    @State private var notFound = false
    @State private var showTimerSheet = false
    @State private var showResetDialog = false
    @State private var powerMode = false

    private static let headerTopPadding: CGFloat = 20
    private static let headerSpacing: CGFloat = 10
    private static let barHeight: CGFloat = 6
    private static let labelSize: CGFloat = 15

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
                model = WirdSessionModel(wirdID: wirdID, environment: environment)
                notFound = model == nil
            }
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
    private func content(_ model: WirdSessionModel) -> some View {
        let settings = environment.settings
        let palette = environment.palette
        let toolbarColor = settings.counterToolbarColor(isSupporter: environment.entitlements.isSupporter)
        let iconColor = ColorMath.readableIcon(accent: palette.toolsAccent, on: toolbarColor)

        ZStack {
            ThemedBackground(color: palette.counterBackground, pattern: environment.showsPattern)
            VStack(spacing: 0) {
                Group {
                    if let item = model.current {
                        DhikrStage(text: item.body, fontSize: CGFloat(settings.fontSize), textColor: palette.counterText,
                                   statsHeight: headerHeight) {
                            header(model, palette: palette)
                        } ring: {
                            ProgressRing(progress: Double(item.count) / Double(max(1, item.target)),
                                         number: NumberText.grouped(item.count),
                                         detail: "/ " + NumberText.grouped(item.target),
                                         palette: palette, numberSize: max(44, CGFloat(settings.fontSize) * 3 - 6))
                        }
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { model.tap() }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("counter.tapArea")
                if !settings.hideNavButtons {
                    PreviousNextBar(color: palette.counterText, previousEnabled: model.hasPrevious,
                                    nextEnabled: model.hasNext, onPrevious: { model.showPrevious() },
                                    onNext: { model.showNext() })
                }
            }
            if powerMode {
                PowerModeOverlay { powerMode = false }
            }
            if model.phase == .finished {
                completedMessage(palette)
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
            TimerSheet(initialDelayMs: model.currentDelayMs) { delay in
                model.startTimer(withDelay: delay)
            }
            .appLanguageAndFont(environment)
        }
        .confirmationDialog(tr("wird.reset.message"), isPresented: $showResetDialog, titleVisibility: .visible) {
            Button(tr("common.reset"), role: .destructive) { model.reset() }
            Button(tr("common.cancel"), role: .cancel) {}
        }
        .alert(tr("wird.continue.title"), isPresented: askBinding(model)) {
            Button(tr("wird.continue")) { model.choose(continueWhereStopped: true) }
            Button(tr("wird.restart")) { model.choose(continueWhereStopped: false) }
            Button(tr("common.cancel"), role: .cancel) { dismiss() }
        } message: {
            Text(tr("wird.continue.message"))
        }
        .alert(tr("error.title"), isPresented: problemBinding(model)) {
            Button(tr("common.ok"), role: .cancel) {
                if model.problem == .missing { dismiss() }
                model.problem = nil
            }
        } message: {
            Text(model.problem == .missing ? tr("counter.missing") : tr("error.save"))
        }
        .task(id: model.phase) {
            guard model.phase == .finished else { return }
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        }
    }

    // MARK: Parts

    /// The wird's name, its overall progress, and the position of the zikr on screen.
    private func header(_ model: WirdSessionModel, palette: ThemePalette) -> some View {
        let color = Color(argb: palette.counterText)
        let font = Font.custom(family.postScriptName(.medium), fixedSize: Self.labelSize)
        return VStack(spacing: Self.headerSpacing) {
            Text(model.name)
                .font(font)
                .lineLimit(1)
                .accessibilityIdentifier("wird.session.name")
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.18))
                    Capsule().fill(Color(argb: palette.ring))
                        .frame(width: geometry.size.width * min(1, max(0, model.progress)))
                }
            }
            .frame(height: Self.barHeight)
            .padding(.horizontal, 32)
            .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text(verbatim: "\(model.index + 1) / \(model.items.count)")
                    .accessibilityIdentifier("wird.session.position")
                if model.current?.status == .skipped {
                    Text(tr("wird.skipped"))
                        .opacity(0.75)
                }
            }
            .font(font)
        }
        .foregroundStyle(color)
        .padding(.top, Self.headerTopPadding)
    }

    private var headerHeight: CGFloat {
        let line = (UIFont(name: family.postScriptName(.medium), size: Self.labelSize)
            ?? .systemFont(ofSize: Self.labelSize)).lineHeight
        return Self.headerTopPadding + line + Self.headerSpacing + Self.barHeight + Self.headerSpacing + line
    }

    private func completedMessage(_ palette: ThemePalette) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54))
            Text(tr("wird.done"))
                .appFont(20, .bold)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color(argb: palette.text))
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(argb: palette.card)))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wird.completed")
    }

    private func actionPill(_ model: WirdSessionModel, iconColor: ARGB) -> some View {
        let icon = Color(argb: iconColor)
        let settings = environment.settings
        return ActionPill(color: icon) {
            PillButton(symbol: model.isTimerRunning ? "pause.fill" : "play.fill", label: tr("counter.a11y.timer"),
                       id: "counter.timer") { model.toggleTimer() }
                .accessibilityValue(model.isTimerRunning ? "running" : "stopped")
            PillDivider(color: icon)
            PillButton(symbol: "moon.fill", label: tr("counter.a11y.power"), id: "counter.power") { powerMode = true }
            PillDivider(color: icon)
            PillButton(symbol: "forward.end.fill", label: tr("wird.skip"), id: "wird.skip") { model.skip() }
            PillDivider(color: icon)
            Menu {
                Button(tr("counter.menu.edit_timer"), systemImage: "timer") {
                    model.stopTimer()
                    showTimerSheet = true
                }
                Button(tr("wird.menu.reset"), systemImage: "arrow.counterclockwise") {
                    showResetDialog = true
                }
                Toggle(isOn: Bindable(settings).vibrateOnTap) {
                    Label(tr("counter.menu.vibration"), systemImage: "iphone.radiowaves.left.and.right")
                }
                Toggle(isOn: Bindable(settings).tapSound) {
                    Label(tr("counter.menu.sound"), systemImage: "speaker.wave.2")
                }
            } label: {
                PillMoreLabel()
            }
            .accessibilityLabel(tr("counter.a11y.more"))
            .accessibilityIdentifier("counter.more")
        }
    }

    private func askBinding(_ model: WirdSessionModel) -> Binding<Bool> {
        Binding(get: { model.phase == .askContinue }, set: { _ in })
    }

    private func problemBinding(_ model: WirdSessionModel) -> Binding<Bool> {
        Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })
    }
}
