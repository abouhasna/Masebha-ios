import Foundation
import Testing
import UIKit
@testable import Masebha

@MainActor
struct SettingsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsMatchTheAndroidApp() {
        let settings = AppSettings(defaults: freshDefaults())
        #expect(settings.language == .arabic)
        #expect(settings.languageChosen == false)
        #expect(settings.themeKey == "theme1")
        #expect(settings.palette == ThemeRegistry.defaultTheme.palette)
        #expect(settings.fontKey == "ibmplexsansarabic")
        #expect(settings.fontSize == 30)
        #expect(settings.scrollableText == true)
        #expect(settings.resumeLoop == false)
        #expect(settings.vibrateOnLoop == true)
        #expect(settings.vibrateOnTap == false)
        #expect(settings.tapVibrationMs == 180)
        #expect(settings.loopVibrationMs == 400)
        #expect(settings.hijriOffset == 0)
        #expect(settings.reminderEnabled == false)
        #expect(settings.reminderHour == 8 && settings.reminderMinute == 0)
    }

    @Test func everyChangeIsSavedImmediately() {
        let defaults = freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.language = .english
        settings.fontSize = 42
        settings.resumeLoop = true
        settings.hijriOffset = -2
        settings.reminderTitle = "Dhikr"
        settings.applyTheme(ThemeRegistry.theme("theme4")!)

        let reloaded = AppSettings(defaults: defaults)   // like the next launch
        #expect(reloaded.language == .english)
        #expect(reloaded.fontSize == 42)
        #expect(reloaded.resumeLoop == true)
        #expect(reloaded.hijriOffset == -2)
        #expect(reloaded.reminderTitle == "Dhikr")
        #expect(reloaded.themeKey == "theme4")
        #expect(reloaded.palette == ThemeRegistry.theme("theme4")!.palette)
    }

    @Test func colorsUseTheAndroidKeys() {
        let defaults = freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.applyTheme(ThemeRegistry.theme("theme3")!)
        #expect(defaults.object(forKey: "cardSelectedColor") as? Int == Int(0xFF2E7D32))
        #expect(defaults.object(forKey: "resetAccentSelectedColor") as? Int == Int(0xFFF0F0F0))
    }

    @Test func invalidStoredValuesFallBackToDefaults() {
        let defaults = freshDefaults()
        defaults.set(31, forKey: "font_size")             // not an allowed size
        defaults.set("x", forKey: "hijri_offset")         // wrong type
        defaults.set(5, forKey: "hijri_offset")           // out of range
        defaults.set("theme99", forKey: "theme")
        defaults.set("comicsans", forKey: "app_font")
        defaults.set(77, forKey: "reminder_hour")
        defaults.set("fr", forKey: "app_language")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.fontSize == 30)
        #expect(settings.hijriOffset == 0)
        #expect(settings.themeKey == "theme1")
        #expect(settings.fontKey == "ibmplexsansarabic")
        #expect(settings.reminderHour == 8)
        #expect(settings.language == .arabic)
    }

    @Test func anIncompletePaletteIsNeverMixed() {
        let defaults = freshDefaults()
        defaults.set(Int(0xFF123456), forKey: "cardSelectedColor")   // only 1 of 11 keys
        let settings = AppSettings(defaults: defaults)
        #expect(settings.palette == ThemeRegistry.defaultTheme.palette)
    }

    // MARK: Supporter themes and fonts (fixes Android issue D5)

    @Test func lockedSupporterThemeShowsTheDefaultButKeepsStoredColors() {
        let settings = AppSettings(defaults: freshDefaults())
        let paid = ThemeRegistry.theme("theme6")!
        settings.applyTheme(paid)
        var custom = paid.palette
        custom.card = 0xFF112233
        settings.palette = custom

        #expect(settings.effectivePalette(isSupporter: false) == ThemeRegistry.defaultTheme.palette)
        #expect(settings.showsPattern(isSupporter: false) == false)
        #expect(settings.effectiveThemeKey(isSupporter: false) == "theme1")
        // Nothing was overwritten: becoming a supporter again restores the custom colors.
        #expect(settings.palette == custom)
        #expect(settings.effectivePalette(isSupporter: true) == custom)
        #expect(settings.showsPattern(isSupporter: true) == true)
    }

    @Test func lockedSupporterFontShowsTheDefaultButKeepsTheChoice() {
        let settings = AppSettings(defaults: freshDefaults())
        settings.fontKey = "cairo"
        #expect(settings.effectiveFont(isSupporter: false).key == "ibmplexsansarabic")
        #expect(settings.effectiveFont(isSupporter: true).key == "cairo")
        #expect(settings.fontKey == "cairo")
    }

    @Test func counterToolbarColorFollowsAndroid() {
        let settings = AppSettings(defaults: freshDefaults())
        settings.applyTheme(ThemeRegistry.theme("theme3")!)
        #expect(settings.counterToolbarColor(isSupporter: false) == settings.palette.ring)
        settings.applyTheme(ThemeRegistry.theme("theme10")!)
        #expect(settings.counterToolbarColor(isSupporter: true) == settings.palette.tools)
    }

    @Test func entitlementIsFalseByDefault() {
        let entitlements = Entitlements(defaults: freshDefaults())
        #expect(entitlements.isSupporter == false)
    }
}

struct ThemeAndFontTests {
    @Test func thirteenThemesWithAndroidKeys() {
        #expect(ThemeRegistry.all.map(\.key) == (1...13).map { "theme\($0)" })
        #expect(ThemeRegistry.all.filter(\.isPaid).map(\.key) == (6...13).map { "theme\($0)" })
    }

    @Test func everyThemeColorIsOpaque() {
        for theme in ThemeRegistry.all {
            for slot in ColorSlot.allCases {
                #expect(theme.palette[slot] >> 24 == 0xFF, "\(theme.key) \(slot)")
            }
        }
    }

    @Test func supporterThemesReuseTextAndBackgroundOnTheCounter() {
        for theme in ThemeRegistry.all where theme.isPaid {
            #expect(theme.palette.counterText == theme.palette.text)
            #expect(theme.palette.counterBackground == theme.palette.background)
        }
    }

    @Test func elevenColorSlotsWithUniqueKeys() {
        #expect(ColorSlot.allCases.count == 11)
        #expect(Set(ColorSlot.allCases.map(\.rawValue)).count == 11)
        #expect(Set(ColorSlot.listScreen + ColorSlot.counterScreen) == Set(ColorSlot.allCases))
    }

    @Test func contrastRules() {
        #expect(ColorMath.isLight(0xFFFFFFFF))
        #expect(!ColorMath.isLight(0xFF000000))
        #expect(abs(ColorMath.contrast(0xFFFFFFFF, 0xFF000000) - 21) < 0.01)
        // White icons on the default green toolbar are readable; on white they are not.
        #expect(ColorMath.readableIcon(accent: 0xFFFFFFFF, on: 0xFF009736) == 0xFFFFFFFF)
        #expect(ColorMath.readableIcon(accent: 0xFFFFFFFF, on: 0xFFFFFFFF) == 0xFF1A1A1A)
    }

    @Test func unknownFontKeyFallsBackToTheDefault() {
        #expect(FontRegistry.family("nope").key == "ibmplexsansarabic")
        #expect(FontRegistry.all.filter { !$0.isPaid }.map(\.key) == ["ibmplexsansarabic", "tajawal"])
    }

    @Test @MainActor func everyBundledFontLoads() {
        for family in FontRegistry.all {
            for weight in [AppFontWeight.extraLight, .light, .regular, .medium, .bold] {
                let name = family.postScriptName(weight)
                #expect(UIFont(name: name, size: 20) != nil, "Font not found: \(name)")
            }
        }
    }

    @Test @MainActor func patternShapeIsParsed() {
        let bounds = KhatamPattern.shape.boundingBoxOfPath
        #expect(!bounds.isEmpty)
        // Inside the vector's viewport (172.91 x 149.48), with a small margin for the stroke.
        #expect(bounds.minX > -5 && bounds.maxX < 178 && bounds.minY > -5 && bounds.maxY < 155)
        let tile = KhatamPattern.tile(base: 0xFF0D1520)
        #expect(tile.size.width == 108 && tile.size.height == 62)
    }
}
