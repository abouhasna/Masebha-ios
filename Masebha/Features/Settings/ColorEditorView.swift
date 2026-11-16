import SwiftUI

/// Advanced colors (≈ ColorPickerActivity): edit each color of the list screen ("Main") or the
/// counter screen ("Dhikr") with the iOS color picker, which also accepts hex codes.
/// "Save" writes the colors of the visible tab; "Default colors" resets that tab (then Save).
struct ColorEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var tab: Tab = .main
    @State private var draft = ThemePalette.placeholder
    @State private var loaded = false
    @State private var saved = false

    enum Tab: Hashable {
        case main, counter
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $tab) {
                    Text(tr("colors.tab.main")).tag(Tab.main)
                    Text(tr("colors.tab.counter")).tag(Tab.counter)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("colors.tab")

                preview
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                ForEach(slots, id: \.self) { slot in
                    ColorPicker(selection: binding(for: slot), supportsOpacity: false) {
                        Text(tr(Self.titleKey(slot)))
                            .appFont(16, .medium)
                            .foregroundStyle(.white)
                    }
                    .settingsRowBackground()
                    .accessibilityIdentifier("colors.\(slot.rawValue)")
                }
            }

            Section {
                Button(tr("colors.default")) {
                    let defaults = ThemeRegistry.defaultTheme.palette
                    for slot in slots { draft[slot] = defaults[slot] }
                }
                .settingsRowBackground()
                .accessibilityIdentifier("colors.default")
                Button {
                    save()
                } label: {
                    Text(tr("common.save")).bold().frame(maxWidth: .infinity)
                }
                .settingsRowBackground()
                .accessibilityIdentifier("colors.save")
            }
        }
        .settingsListStyle()
        .navigationTitle(tr("settings.advanced"))
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigationBar(environment.palette.tools)
        .onAppear {
            if !loaded {
                draft = environment.palette
                loaded = true
            }
        }
        .alert(tr("colors.saved"), isPresented: $saved) {
            Button(tr("common.ok"), role: .cancel) {}
        }
    }

    private var slots: [ColorSlot] {
        tab == .main ? ColorSlot.listScreen : ColorSlot.counterScreen
    }

    private func binding(for slot: ColorSlot) -> Binding<Color> {
        Binding(get: { Color(argb: draft[slot]) },
                set: { draft[slot] = ColorMath.opaque($0.argb()) })
    }

    /// Saves only the colors of the visible tab. The theme key stays (like Android).
    private func save() {
        var palette = environment.settings.palette
        for slot in slots { palette[slot] = draft[slot] }
        environment.settings.palette = palette
        saved = true
    }

    @ViewBuilder
    private var preview: some View {
        if tab == .main {
            VStack(spacing: 0) {
                HStack {
                    Text(verbatim: "١ رمضان ١٤٤٧")
                        .appFont(14, .bold)
                        .foregroundStyle(Color(argb: draft.toolsAccent))
                    Spacer()
                }
                .padding(10)
                .background(Color(argb: draft.tools))
                VStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { _ in
                        HStack {
                            Text(tr("seed.subhan_allah")).appFont(17, .medium)
                            Spacer()
                            Text(verbatim: "33").appFont(13, .regular)
                        }
                        .foregroundStyle(Color(argb: draft.text))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(argb: draft.card)))
                    }
                }
                .padding(10)
            }
            .background(Color(argb: draft.background))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(spacing: 10) {
                Text(tr("seed.subhan_allah"))
                    .appFont(18, .light)
                    .foregroundStyle(Color(argb: draft.counterText))
                ProgressRing(current: 12, loopSize: 33, palette: draft, numberSize: 40)
                    .frame(width: 130, height: 130)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(argb: draft.counterBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    static func titleKey(_ slot: ColorSlot) -> String {
        switch slot {
        case .card: "colors.card"
        case .background, .counterBackground: "colors.background"
        case .text, .counterText: "colors.text"
        case .tools: "colors.tools"
        case .toolsAccent: "colors.tools_text"
        case .progressButton: "colors.progress_button"
        case .progressText: "colors.progress_text"
        case .ring: "colors.ring"
        case .ringTrack: "colors.ring_track"
        }
    }
}

extension ThemePalette {
    /// Initial value before the real colors load.
    static var placeholder: ThemePalette { ThemeRegistry.defaultTheme.palette }
}
