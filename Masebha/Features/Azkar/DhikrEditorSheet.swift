import SwiftUI

enum DhikrEditorMode: Identifiable {
    case add
    case edit(Dhikr)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let dhikr): "edit-\(dhikr.id)"
        }
    }

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}

/// Add or edit a dhikr: text, beads per loop, and the count (≈ add_dialog.xml).
struct DhikrEditorSheet: View {
    let mode: DhikrEditorMode
    let onSave: (DhikrForm.Output) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var loopSize: String
    @State private var total: String
    @State private var problem: String?

    init(mode: DhikrEditorMode, onSave: @escaping (DhikrForm.Output) throws -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _loopSize = State(initialValue: "")
            _total = State(initialValue: "")
        case .edit(let dhikr):
            _name = State(initialValue: dhikr.name)
            _loopSize = State(initialValue: String(dhikr.loopSize))
            _total = State(initialValue: String(dhikr.total))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("editor.name"), text: $name, axis: .vertical)
                        .lineLimit(1...6)
                        .appFont(18, .regular)
                        .accessibilityIdentifier("editor.name")
                } header: {
                    Text(tr("editor.name"))
                }
                Section {
                    TextField(tr("editor.loop_size"), text: $loopSize)
                        .keyboardType(.numberPad)
                        .appFont(18, .regular)
                        .accessibilityIdentifier("editor.loopSize")
                        .onChange(of: loopSize) { _, value in
                            let clean = DhikrForm.digitsOnly(value, maxDigits: DhikrForm.maxLoopDigits)
                            if clean != value { loopSize = clean }
                        }
                } header: {
                    Text(tr("editor.loop_size"))
                }
                Section {
                    TextField(mode.isEdit ? tr("editor.total") : tr("editor.previous_count"), text: $total)
                        .keyboardType(.numberPad)
                        .appFont(18, .regular)
                        .accessibilityIdentifier("editor.total")
                        .onChange(of: total) { _, value in
                            let clean = DhikrForm.digitsOnly(value, maxDigits: DhikrForm.maxTotalDigits)
                            if clean != value { total = clean }
                        }
                } header: {
                    Text(mode.isEdit ? tr("editor.total") : tr("editor.previous_count"))
                }
                if let problem {
                    Section {
                        Text(problem)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("editor.problem")
                    }
                }
            }
            .navigationTitle(mode.isEdit ? tr("editor.title.edit") : tr("editor.title.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("common.cancel")) { dismiss() }
                        .accessibilityIdentifier("editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.isEdit ? tr("common.save") : tr("common.add")) { save() }
                        .bold()
                        .accessibilityIdentifier("editor.save")
                }
            }
        }
        .tint(Color(argb: SettingsStyle.accent))
        .presentationDetents([.large])
        // An old error message disappears as soon as the user corrects a field.
        .onChange(of: name) { problem = nil }
        .onChange(of: loopSize) { problem = nil }
        .onChange(of: total) { problem = nil }
    }

    private func save() {
        switch DhikrForm.validate(name: name, loopSize: loopSize, total: total, isEdit: mode.isEdit) {
        case .failure(.missingFields):
            problem = tr("editor.error.fill")
        case .failure(.zeroLoop):
            problem = tr("editor.error.zero")
        case .success(let output):
            do {
                try onSave(output)
                dismiss()
            } catch {
                problem = tr("error.save")
            }
        }
    }
}
