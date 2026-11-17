import SwiftUI

/// The home screen: the user's adhkar as cards (≈ MainActivity + MyAdapter on Android).
/// Tap a card to count, ⋮ for edit / reset / reorder / delete.
/// Reordering: press and hold a card, then drag it (iOS lifts it, like Android), at any time.
/// "⋮ → Reorder" opens a reorder mode that makes this visible: a ≡ on every card, a hint, and
/// cards that do not open while it is on. Every move is saved immediately.
struct AzkarListView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    let onOpen: (Int64) -> Void

    @State private var items: [Dhikr] = []
    @State private var now = Date()
    @State private var editor: DhikrEditorMode?
    @State private var pendingReset: Dhikr?
    @State private var pendingDelete: Dhikr?
    @State private var errorMessage: String?
    @State private var reordering = false

    var body: some View {
        let palette = environment.palette
        List {
            ForEach(items) { item in
                DhikrCard(dhikr: item, palette: palette, now: now, isReordering: reordering,
                          onEdit: { editor = .edit(item) },
                          onReset: { pendingReset = item },
                          onReorder: startReordering,
                          onDelete: { pendingDelete = item })
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !reordering { onOpen(item.id) }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            // Press and hold, then drag (no edit mode needed since iOS 16).
            .onMove(perform: move)
        }
        .listStyle(.plain)
        // System parts of the list (menus, the lifted card) follow the background: dark on dark themes.
        .environment(\.colorScheme, ColorMath.isLight(palette.background) ? .light : .dark)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 88, for: .scrollContent)   // the last card is never hidden by "+"
        .background(ThemedBackground(color: palette.background, pattern: environment.showsPattern))
        .overlay {
            if items.isEmpty {
                Text(tr("list.empty"))
                    .appFont(17, .regular)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(argb: ColorMath.isLight(palette.background) ? 0xFF1E_1E1E : 0xFFFF_FFFF))
                    .opacity(0.7)
                    .padding(40)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !reordering { addButton(palette) }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if reordering { reorderHint(palette) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The title area (not a bar button), so iOS 26 does not wrap it in a glass capsule.
            ToolbarItem(placement: .principal) {
                HijriHeader(color: ColorMath.readableIcon(accent: palette.toolsAccent, on: palette.tools),
                            offset: environment.settings.hijriOffset,
                            language: environment.settings.language, now: now)
            }
            if reordering {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("common.done")) {
                        withAnimation { reordering = false }
                    }
                    .bold()
                    .accessibilityIdentifier("list.doneReordering")
                }
            }
        }
        .themedNavigationBar(palette.tools)
        .sheet(item: $editor) { mode in
            DhikrEditorSheet(mode: mode) { output in
                try save(output, mode: mode)
            }
            .appLanguageAndFont(environment)
        }
        .alert(tr("common.reset"), isPresented: isPresented($pendingReset), presenting: pendingReset) { item in
            Button(tr("common.reset"), role: .destructive) { reset(item) }
            Button(tr("common.cancel"), role: .cancel) {}
        } message: { _ in
            Text(tr("list.reset.message"))
        }
        .alert(tr("common.delete"), isPresented: isPresented($pendingDelete), presenting: pendingDelete) { item in
            Button(tr("common.delete"), role: .destructive) { delete(item) }
            Button(tr("common.cancel"), role: .cancel) {}
        } message: { _ in
            Text(tr("list.delete.message"))
        }
        .alert(tr("error.title"), isPresented: isPresented($errorMessage)) {
            Button(tr("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reload() }
        }
    }

    private func addButton(_ palette: ThemePalette) -> some View {
        Button {
            editor = .add
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color(argb: ColorMath.readableIcon(accent: palette.toolsAccent, on: palette.tools)))
                .frame(width: 60, height: 60)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(argb: palette.tools)))
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityLabel(tr("list.add"))
        .accessibilityIdentifier("list.add")
    }

    /// Under the toolbar, in its colors, while reorder mode is on.
    private func reorderHint(_ palette: ThemePalette) -> some View {
        Text(tr("list.reorder.hint"))
            .appFont(14, .medium)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(argb: ColorMath.readableIcon(accent: palette.toolsAccent, on: palette.tools)))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(argb: palette.tools))
            .accessibilityIdentifier("list.reorderHint")
    }

    // MARK: Actions

    private func startReordering() {
        guard items.count > 1 else { return }
        withAnimation { reordering = true }
    }

    private func reload() {
        now = Date()
        do {
            items = try environment.store.allDhikr()
        } catch {
            errorMessage = tr("error.load")
        }
    }

    private func save(_ output: DhikrForm.Output, mode: DhikrEditorMode) throws {
        switch mode {
        case .add:
            _ = try environment.store.add(name: output.name, loopSize: output.loopSize, initialTotal: output.total)
        case .edit(let dhikr):
            try environment.store.update(id: dhikr.id, name: output.name, loopSize: output.loopSize, total: output.total)
        }
        reload()
    }

    private func reset(_ item: Dhikr) {
        do {
            try environment.store.resetCount(of: item.id, day: DayKey.today())
        } catch {
            errorMessage = tr("error.save")
        }
        reload()
    }

    private func delete(_ item: Dhikr) {
        do {
            try environment.store.delete(id: item.id)
        } catch {
            errorMessage = tr("error.save")
        }
        reload()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = items
        reordered.move(fromOffsets: source, toOffset: destination)
        items = reordered
        do {
            try environment.store.reorder(reordered.map(\.id))
        } catch {
            errorMessage = tr("error.save")
        }
        reload()
    }
}

/// Turns an optional into the Bool binding an alert needs.
func isPresented<T>(_ value: Binding<T?>) -> Binding<Bool> {
    Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
}

/// Weekday and Hijri date in the toolbar (≈ the Android toolbar header).
struct HijriHeader: View {
    let color: ARGB
    let offset: Int
    let language: AppLanguage
    let now: Date

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text(HijriDate.weekday(for: now, language: language))
                .appFont(13, .medium)
                .opacity(0.9)
            Text(HijriDate.text(for: now, offsetDays: offset, language: language))
                .appFont(17, .bold)
                .accessibilityIdentifier("list.hijriDate")
        }
        .foregroundStyle(Color(argb: color))
        .fixedSize()
    }
}
