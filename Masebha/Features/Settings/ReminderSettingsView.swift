import SwiftUI
import UIKit

/// The daily reminder (≈ the reminder dialog on Android): on/off, title and time.
/// After saving, the screen shows the state iOS really has, so a refused permission is visible.
struct ReminderSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var enabled = false
    @State private var title = ""
    @State private var time = Date()
    @State private var loaded = false
    @State private var saving = false
    @State private var showPermissionAlert = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $enabled) {
                    Text(tr("reminder.enable")).appFont(16, .medium).foregroundStyle(.white)
                }
                .settingsRowBackground()
                .accessibilityIdentifier("reminder.enabled")

                TextField(tr("app.name"), text: $title)
                    .appFont(16, .regular)
                    .foregroundStyle(.white)
                    .settingsRowBackground()
                    .accessibilityIdentifier("reminder.title")

                DatePicker(selection: $time, displayedComponents: .hourAndMinute) {
                    Text(tr("reminder.time")).appFont(16, .medium).foregroundStyle(.white)
                }
                .environment(\.locale, Locale(identifier: "en_GB"))   // 24-hour clock, ASCII digits
                .settingsRowBackground()
                .accessibilityIdentifier("reminder.time")
            } header: {
                Text(tr("reminder.title_hint")).textCase(nil)
            } footer: {
                Text(statusText)
                    .appFont(14, .regular)
                    .accessibilityIdentifier("reminder.status")
            }

            Section {
                Button {
                    save()
                } label: {
                    Text(tr("common.save")).bold().frame(maxWidth: .infinity)
                }
                .disabled(saving)
                .settingsRowBackground()
                .accessibilityIdentifier("reminder.save")
            }
        }
        .settingsListStyle()
        .navigationTitle(tr("settings.reminder"))
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigationBar(environment.palette.tools)
        .onAppear(perform: load)
        .alert(tr("reminder.permission"), isPresented: $showPermissionAlert) {
            Button(tr("reminder.open_settings")) {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(tr("common.cancel"), role: .cancel) {}
        }
    }

    private var statusText: String {
        switch environment.reminderStatus {
        case .off: tr("reminder.status.off")
        case .scheduled(let hour, let minute): tr("reminder.status.on", String(format: "%02d:%02d", hour, minute))
        case .notAllowed: tr("reminder.status.denied")
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let settings = environment.settings
        enabled = settings.reminderEnabled
        title = settings.reminderTitle
        var components = DateComponents()
        components.hour = settings.reminderHour
        components.minute = settings.reminderMinute
        time = Calendar.current.date(from: components) ?? Date()
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        saving = true
        Task {
            await environment.saveReminder(enabled: enabled, title: title,
                                           hour: parts.hour ?? 8, minute: parts.minute ?? 0)
            saving = false
            if environment.reminderStatus == .notAllowed {
                showPermissionAlert = true
            }
        }
    }
}
