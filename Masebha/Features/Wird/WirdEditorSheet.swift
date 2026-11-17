import SwiftUI

enum WirdEditorMode: Identifiable {
    case add
    case edit(id: Int64, name: String, drafts: [WirdDraft])

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let id, _, _): "edit-\(id)"
        }
    }

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}

/// Add or edit a wird: its name and any number of azkar, each with a target (≈ WirdEditorDialog).
struct WirdEditorSheet: View {
    let mode: WirdEditorMode
    let onSave: (NewWird) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var rows: [EditableRow]
    @State private var problem: String?

    private struct EditableRow: Identifiable {
        let id = UUID()
        var itemID: Int64 = 0
        var body = ""
        var target = ""
    }

    init(mode: WirdEditorMode, onSave: @escaping (NewWird) throws -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _rows = State(initialValue: [EditableRow()])
        case .edit(_, let name, let drafts):
            _name = State(initialValue: name)
            _rows = State(initialValue: drafts.map {
                EditableRow(itemID: $0.itemID, body: $0.body, target: String($0.target))
            })
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("wird.editor.name"), text: $name)
                        .appFont(18, .regular)
                        .accessibilityIdentifier("wird.editor.name")
                } header: {
                    Text(tr("wird.editor.name"))
                }

                ForEach($rows) { $row in
                    Section {
                        TextField(tr("wird.editor.zikr"), text: $row.body, axis: .vertical)
                            .lineLimit(1...8)
                            .appFont(18, .regular)
                            .accessibilityIdentifier("wird.editor.zikr")
                        HStack {
                            Text(tr("wird.editor.target"))
                                .appFont(16, .regular)
                                .foregroundStyle(.secondary)
                            TextField("33", text: $row.target)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .appFont(18, .regular)
                                .accessibilityIdentifier("wird.editor.target")
                                .onChange(of: row.target) { _, value in
                                    let clean = DhikrForm.digitsOnly(value, maxDigits: WirdForm.maxTargetDigits)
                                    if clean != value { row.target = clean }
                                }
                        }
                        if rows.count > 1 {
                            Button(role: .destructive) {
                                rows.removeAll { $0.id == row.id }
                            } label: {
                                Label(tr("wird.editor.remove_row"), systemImage: "minus.circle")
                            }
                            .accessibilityIdentifier("wird.editor.removeRow")
                        }
                    } header: {
                        Text(verbatim: "\((rows.firstIndex { $0.id == row.id } ?? 0) + 1)")
                    }
                }

                Section {
                    Button {
                        rows.append(EditableRow())
                    } label: {
                        Label(tr("wird.editor.add_row"), systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("wird.editor.addRow")
                }

                if let problem {
                    Section {
                        Text(problem)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("wird.editor.problem")
                    }
                }
            }
            .navigationTitle(mode.isEdit ? tr("wird.editor.title.edit") : tr("wird.editor.title.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("common.cancel")) { dismiss() }
                        .accessibilityIdentifier("wird.editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.isEdit ? tr("common.save") : tr("common.add")) { save() }
                        .bold()
                        .accessibilityIdentifier("wird.editor.save")
                }
            }
        }
        .tint(Color(argb: SettingsStyle.accent))
        .presentationDetents([.large])
        .onChange(of: name) { problem = nil }
    }

    private func save() {
        let formRows = rows.map { WirdForm.Row(itemID: $0.itemID, body: $0.body, target: $0.target) }
        switch WirdForm.validate(name: name, rows: formRows) {
        case .failure(.nameRequired):
            problem = tr("wird.problem.name")
        case .failure(.needItem):
            problem = tr("wird.problem.need_item")
        case .failure(.fillItems):
            problem = tr("wird.problem.fill")
        case .success(let wird):
            do {
                try onSave(wird)
                dismiss()
            } catch {
                problem = tr("error.save")
            }
        }
    }
}
