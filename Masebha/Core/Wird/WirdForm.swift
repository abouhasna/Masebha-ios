import Foundation

/// Validation of the wird editor (same rules and messages as Android's WirdEditorDialog):
/// a name, at least one zikr, and every zikr with text and a target of 1…99,999.
nonisolated enum WirdForm {
    static let maxTargetDigits = 5

    struct Row: Equatable, Sendable {
        var itemID: Int64 = 0
        var body: String
        var target: String
    }

    enum Problem: Error, Equatable {
        case nameRequired   // "Enter a name for the wird"
        case needItem       // "Add at least one zikr"
        case fillItems      // "Fill in the text and target of every zikr"
    }

    static func validate(name: String, rows: [Row]) -> Result<NewWird, Problem> {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .failure(.nameRequired) }
        guard !rows.isEmpty else { return .failure(.needItem) }
        var items: [WirdDraft] = []
        for row in rows {
            let body = row.body.trimmingCharacters(in: .whitespacesAndNewlines)
            let digits = row.target.trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty, (1...maxTargetDigits).contains(digits.count),
                  digits.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let target = Int(digits), target > 0 else { return .failure(.fillItems) }
            items.append(WirdDraft(itemID: row.itemID, body: body, target: target))
        }
        return .success(NewWird(name: trimmedName, items: items))
    }
}
