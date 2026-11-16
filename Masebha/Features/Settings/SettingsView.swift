import SwiftUI

/// Settings (≈ SettingsActivity + root_preferences.xml). Every change is saved immediately.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var settings = environment.settings
        let isSupporter = environment.entitlements.isSupporter
        let themeKey = settings.effectiveThemeKey(isSupporter: isSupporter)

        List {
            Section {
                NavigationLink {
                    ThemePickerView()
                } label: {
                    SettingsRowLabel(icon: "paintbrush.fill", title: tr("settings.theme"),
                                     subtitle: tr(ThemeRegistry.theme(themeKey)?.nameKey ?? "theme.theme1"))
                }
                .settingsRowBackground()
                .accessibilityIdentifier("settings.theme")

                NavigationLink {
                    ColorEditorView()
                } label: {
                    SettingsRowLabel(icon: "paintpalette.fill", title: tr("settings.advanced"),
                                     subtitle: tr("settings.advanced.summary"))
                }
                .settingsRowBackground()
                .accessibilityIdentifier("settings.colors")

                Picker(selection: $settings.fontSize) {
                    ForEach(SettingOptions.fontSizes.indices, id: \.self) { index in
                        Text(tr(Self.fontSizeKeys[index])).tag(SettingOptions.fontSizes[index])
                    }
                } label: {
                    SettingsRowLabel(icon: "textformat.size", title: tr("settings.font_size"),
                                     subtitle: tr("settings.font_size.summary"))
                }
                .pickerStyle(.navigationLink)
                .settingsRowBackground()
                .accessibilityIdentifier("settings.fontSize")

                NavigationLink {
                    FontPickerView()
                } label: {
                    SettingsRowLabel(icon: "textformat", title: tr("settings.font"),
                                     subtitle: environment.fontFamily.displayName)
                }
                .settingsRowBackground()
                .accessibilityIdentifier("settings.font")
            } header: {
                sectionHeader(tr("settings.section.appearance"))
            }

            Section {
                NavigationLink {
                    ReminderSettingsView()
                } label: {
                    SettingsRowLabel(icon: "bell.fill", title: tr("settings.reminder"), subtitle: reminderSummary)
                }
                .settingsRowBackground()
                .accessibilityIdentifier("settings.reminder")
            } header: {
                sectionHeader(tr("settings.section.reminder"))
            }

            Section {
                toggle($settings.scrollableText, icon: "text.alignright", title: tr("settings.scrollable_text"),
                       id: "settings.scrollableText")
                toggle($settings.resumeLoop, icon: "arrow.uturn.forward", title: tr("settings.resume_loop"),
                       subtitle: tr("settings.resume_loop.summary"), id: "settings.resumeLoop")
                toggle($settings.stopTimerOnLoop, icon: "pause.fill", title: tr("settings.stop_timer_on_loop"),
                       id: "settings.stopTimerOnLoop")
                toggle($settings.nextDhikrOnLoop, icon: "arrow.left.arrow.right", title: tr("settings.next_on_loop"),
                       id: "settings.nextOnLoop")
                toggle($settings.hideNavButtons, icon: "rectangle.split.2x1", title: tr("settings.hide_nav"),
                       id: "settings.hideNav")
                toggle($settings.loopSound, icon: "speaker.wave.2.fill", title: tr("settings.loop_sound"),
                       subtitle: tr("settings.loop_sound.summary"), id: "settings.loopSound")
                NavigationLink {
                    VibrationPickerView(title: tr("settings.tap_vibration"), options: SettingOptions.tapVibrationMs,
                                        selection: $settings.tapVibrationMs)
                } label: {
                    SettingsRowLabel(icon: "waveform", title: tr("settings.tap_vibration"),
                                     subtitle: vibrationLabel(settings.tapVibrationMs, in: SettingOptions.tapVibrationMs))
                }
                .settingsRowBackground()
                .accessibilityIdentifier("settings.tapVibration")
                toggle($settings.vibrateOnLoop, icon: "iphone.radiowaves.left.and.right",
                       title: tr("settings.vibrate_loop"), subtitle: tr("settings.vibrate_loop.summary"),
                       id: "settings.vibrateLoop")
                NavigationLink {
                    VibrationPickerView(title: tr("settings.loop_vibration"), options: SettingOptions.loopVibrationMs,
                                        selection: $settings.loopVibrationMs)
                } label: {
                    SettingsRowLabel(icon: "waveform.path", title: tr("settings.loop_vibration"),
                                     subtitle: vibrationLabel(settings.loopVibrationMs, in: SettingOptions.loopVibrationMs))
                }
                .settingsRowBackground()
                .accessibilityIdentifier("settings.loopVibration")
            } header: {
                sectionHeader(tr("settings.section.counter"))
            }

            Section {
                Picker(selection: $settings.hijriOffset) {
                    ForEach(SettingOptions.hijriOffsets.indices, id: \.self) { index in
                        Text(tr(Self.hijriKeys[index])).tag(SettingOptions.hijriOffsets[index])
                    }
                } label: {
                    SettingsRowLabel(icon: "calendar", title: tr("settings.hijri_offset"),
                                     subtitle: tr("settings.hijri_offset.summary"))
                }
                .pickerStyle(.navigationLink)
                .settingsRowBackground()
                .accessibilityIdentifier("settings.hijriOffset")
            } header: {
                sectionHeader(tr("settings.section.hijri"))
            }

            Section {
                Picker(selection: Binding(get: { settings.language },
                                          set: { environment.changeLanguage(to: $0) })) {
                    Text(verbatim: "العربية").tag(AppLanguage.arabic)
                    Text(verbatim: "English").tag(AppLanguage.english)
                } label: {
                    SettingsRowLabel(icon: "globe", title: tr("settings.language"))
                }
                .pickerStyle(.navigationLink)
                .settingsRowBackground()
                .accessibilityIdentifier("settings.language")
            } header: {
                sectionHeader(tr("settings.section.language"))
            }

            #if DEBUG
            Section {
                Toggle(isOn: Bindable(environment.entitlements).isSupporter) {
                    SettingsRowLabel(icon: "ladybug.fill", title: "Supporter (debug only)")
                }
                .settingsRowBackground()
                .accessibilityIdentifier("settings.debugSupporter")
            } header: {
                sectionHeader("Debug")
            }
            #endif
        }
        .settingsListStyle()
        .navigationTitle(tr("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigationBar(environment.palette.tools)
    }

    static let fontSizeKeys = ["font_size.tiny", "font_size.small", "font_size.medium", "font_size.large", "font_size.huge"]
    static let hijriKeys = ["hijri.minus2", "hijri.minus1", "hijri.none", "hijri.plus1", "hijri.plus2"]
    static let vibrationKeys = ["vibration.very_short", "vibration.short", "vibration.medium", "vibration.long",
                                "vibration.very_long"]

    private var reminderSummary: String {
        switch environment.reminderStatus {
        case .off: tr("reminder.status.off")
        case .scheduled(let hour, let minute): tr("reminder.status.on", String(format: "%02d:%02d", hour, minute))
        case .notAllowed: tr("reminder.status.denied")
        }
    }

    private func vibrationLabel(_ value: Int, in options: [Int]) -> String {
        guard let index = options.firstIndex(of: value) else { return "" }
        return tr(Self.vibrationKeys[index])
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .appFont(15, .bold)
            .foregroundStyle(.white)
            .textCase(nil)
    }

    private func toggle(_ value: Binding<Bool>, icon: String, title: String, subtitle: String? = nil,
                        id: String) -> some View {
        Toggle(isOn: value) {
            SettingsRowLabel(icon: icon, title: title, subtitle: subtitle)
        }
        .settingsRowBackground()
        .accessibilityIdentifier(id)
    }
}

/// Vibration length list; choosing an option vibrates with it, so the user feels the difference.
struct VibrationPickerView: View {
    let title: String
    let options: [Int]
    @Binding var selection: Int
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        List {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index]
                Button {
                    selection = value
                    environment.haptics.vibrate(milliseconds: value)
                } label: {
                    HStack {
                        Text(tr(SettingsView.vibrationKeys[index]))
                            .appFont(17, .regular)
                            .foregroundStyle(.white)
                        Spacer()
                        if value == selection {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color(argb: SettingsStyle.accent))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .settingsRowBackground()
                .accessibilityIdentifier("vibration.\(value)")
            }
        }
        .settingsListStyle()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigationBar(environment.palette.tools)
    }
}
