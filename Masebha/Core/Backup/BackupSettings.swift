import Foundation

/// Settings and colors in backup files, with Android's keys *and value types*: list choices are
/// text ("30"), switches are booleans, the reminder time is a number. Android reads each key with
/// one fixed type, so writing another type would break the import there.
extension AppSettings {
    /// Android preference keys written to a backup. (`service_sound` has no meaning on iOS.)
    func backupSettings() -> [String: JSONValue] {
        [
            Keys.theme: .string(themeKey),
            Keys.fontSize: .string(String(fontSize)),
            Keys.font: .string(fontKey),
            Keys.tapSound: .bool(tapSound),
            Keys.loopSound: .bool(loopSound),
            Keys.vibrateOnTap: .bool(vibrateOnTap),
            Keys.vibrateOnLoop: .bool(vibrateOnLoop),
            Keys.tapVibrationMs: .string(String(tapVibrationMs)),
            Keys.loopVibrationMs: .string(String(loopVibrationMs)),
            Keys.resumeLoop: .bool(resumeLoop),
            Keys.hijriOffset: .string(String(hijriOffset)),
            Keys.reminderEnabled: .bool(reminderEnabled),
            Keys.reminderTitle: .string(reminderTitle),
            Keys.reminderHour: .int(Int64(reminderHour)),
            Keys.reminderMinute: .int(Int64(reminderMinute)),
            Keys.language: .string(language.rawValue),
        ]
    }

    /// The 11 colors as Android stores them: signed 32-bit integers.
    func backupColors() -> [String: Int64] {
        Dictionary(uniqueKeysWithValues: ColorSlot.allCases.map { slot in
            (slot.rawValue, Int64(Int32(bitPattern: palette[slot])))
        })
    }

    /// Applies a backup's settings and colors. Every value is checked like a stored one: an
    /// unknown key, a wrong type or an out-of-range value is ignored and the current value stays.
    /// The language is applied by the caller (it also switches the UI).
    func applyBackup(settings values: [String: JSONValue], colors: [String: Int64]?) {
        if let value = values[Keys.theme]?.string, ThemeRegistry.theme(value) != nil { themeKey = value }
        if let value = values[Keys.font]?.string, FontRegistry.all.contains(where: { $0.key == value }) {
            fontKey = value
        }
        if let value = values[Keys.fontSize]?.intOrNumericString, SettingOptions.fontSizes.contains(value) {
            fontSize = value
        }
        if let value = values[Keys.tapSound]?.bool { tapSound = value }
        if let value = values[Keys.loopSound]?.bool { loopSound = value }
        if let value = values[Keys.vibrateOnTap]?.bool { vibrateOnTap = value }
        if let value = values[Keys.vibrateOnLoop]?.bool { vibrateOnLoop = value }
        if let value = values[Keys.tapVibrationMs]?.intOrNumericString, SettingOptions.tapVibrationMs.contains(value) {
            tapVibrationMs = value
        }
        if let value = values[Keys.loopVibrationMs]?.intOrNumericString, SettingOptions.loopVibrationMs.contains(value) {
            loopVibrationMs = value
        }
        if let value = values[Keys.resumeLoop]?.bool { resumeLoop = value }
        if let value = values[Keys.hijriOffset]?.intOrNumericString, SettingOptions.hijriOffsets.contains(value) {
            hijriOffset = value
        }
        if let value = values[Keys.reminderEnabled]?.bool { reminderEnabled = value }
        if let value = values[Keys.reminderTitle]?.string { reminderTitle = value }
        if let value = values[Keys.reminderHour]?.intOrNumericString, (0...23).contains(value) { reminderHour = value }
        if let value = values[Keys.reminderMinute]?.intOrNumericString, (0...59).contains(value) { reminderMinute = value }

        // Android rule: a missing or 0 color means that color's default.
        if let colors {
            var restored = ThemeRegistry.defaultTheme.palette
            for slot in ColorSlot.allCases {
                if let value = colors[slot.rawValue], value != 0, let signed = Int32(exactly: value) {
                    restored[slot] = ARGB(bitPattern: signed)
                }
            }
            palette = restored
        }
    }
}
