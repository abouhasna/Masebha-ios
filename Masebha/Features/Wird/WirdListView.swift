import SwiftUI

/// The supporter's wirds (≈ the wird page of MainActivity). Tap a wird to go through it,
/// ⋮ for edit / reset / reorder / delete, press and hold to drag it to another place.
struct WirdListView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    let onOpen: (Int64) -> Void

    @State private var items: [WirdSummary] = []
    @State private var editor: WirdEditorMode?
    @State private var pendingReset: WirdSummary?
    @State private var pendingDelete: WirdSummary?
    @State private var errorMessage: String?
    @State private var reordering = false

    var body: some View {
        let palette = environment.palette
        List {
            ForEach(items) { item in
                WirdCard(wird: item, palette: palette, isReordering: reordering,
                         onEdit: { edit(item) },
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
            .onMove(perform: move)   // press and hold, then drag
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 88, for: .scrollContent)   // the last card is never hidden by "+"
        .background(ThemedBackground(color: palette.background, pattern: environment.showsPattern))
        .overlay {
            if items.isEmpty {
                Text(tr("wird.empty"))
                    .appFont(17, .regular)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(argb: ColorMath.isLight(palette.background) ? 0xFF1E_1E1E : 0xFFFF_FFFF))
                    .opacity(0.7)
                    .padding(40)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !reordering {
                FloatingAddButton(palette: palette, label: tr("wird.add"), id: "wird.add") { editor = .add }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if reordering {
                ReorderBar(palette: palette) { withAnimation { reordering = false } }
            }
        }
        .navigationTitle(tr("tab.wird"))
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigationBar(palette.tools)
        .sheet(item: $editor) { mode in
            WirdEditorSheet(mode: mode) { wird in
                try save(wird, mode: mode)
            }
            .appLanguageAndFont(environment)
        }
        .alert(tr("common.reset"), isPresented: isPresented($pendingReset), presenting: pendingReset) { item in
            Button(tr("common.reset"), role: .destructive) { reset(item) }
            Button(tr("common.cancel"), role: .cancel) {}
        } message: { _ in
            Text(tr("wird.reset.message"))
        }
        .alert(tr("common.delete"), isPresented: isPresented($pendingDelete), presenting: pendingDelete) { item in
            Button(tr("common.delete"), role: .destructive) { delete(item) }
            Button(tr("common.cancel"), role: .cancel) {}
        } message: { _ in
            Text(tr("wird.delete.message"))
        }
        .alert(tr("error.title"), isPresented: isPresented($errorMessage)) {
            Button(tr("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear(perform: appear)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reload() }
        }
    }

    // MARK: Actions

    private func appear() {
        // The first visit adds the default wirds; if that fails, it is tried again next time.
        try? environment.addDefaultWirdsIfNeeded()
        reload()
    }

    private func reload() {
        do {
            items = try environment.wirdStore.summaries(day: DayKey.today())
        } catch {
            errorMessage = tr("error.load")
        }
    }

    private func startReordering() {
        guard items.count > 1 else { return }
        withAnimation { reordering = true }
    }

    private func edit(_ item: WirdSummary) {
        do {
            editor = .edit(id: item.id, name: item.name, drafts: try environment.wirdStore.drafts(of: item.id))
        } catch {
            errorMessage = tr("error.load")
        }
    }

    private func save(_ wird: NewWird, mode: WirdEditorMode) throws {
        switch mode {
        case .add:
            try environment.wirdStore.add(wird, now: Date())
        case .edit(let id, _, _):
            try environment.wirdStore.update(id: id, with: wird, day: DayKey.today(), now: Date())
        }
        reload()
    }

    private func reset(_ item: WirdSummary) {
        do {
            try environment.wirdStore.resetDay(item.id, day: DayKey.today())
        } catch {
            errorMessage = tr("error.save")
        }
        reload()
    }

    private func delete(_ item: WirdSummary) {
        do {
            try environment.wirdStore.delete(id: item.id)
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
            try environment.wirdStore.reorder(reordered.map(\.id))
        } catch {
            errorMessage = tr("error.save")
        }
        reload()
    }
}
