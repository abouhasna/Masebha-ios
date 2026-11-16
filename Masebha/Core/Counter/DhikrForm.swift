import Foundation

/// Validation of the add / edit dhikr form (same rules as the Android dialog).
nonisolated enum DhikrForm {
    static let maxLoopDigits = 5    // up to 99,999 beads per loop
    static let maxTotalDigits = 7   // up to 9,999,999

    struct Output: Equatable, Sendable {
        let name: String
        let loopSize: Int
        let total: Int
    }

    enum Problem: Error, Equatable {
        case missingFields   // "Please fill in the fields"
        case zeroLoop        // "Beads count cannot be zero"
    }

    /// `isEdit`: the total field is required when editing, optional ("previous count") when adding.
    static func validate(name: String, loopSize: String, total: String, isEdit: Bool) -> Result<Output, Problem> {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let loopText = loopSize.trimmingCharacters(in: .whitespaces)
        let totalText = total.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty, !loopText.isEmpty else { return .failure(.missingFields) }
        guard let loop = number(loopText, maxDigits: maxLoopDigits) else { return .failure(.missingFields) }
        guard loop > 0 else { return .failure(.zeroLoop) }

        let totalValue: Int
        if totalText.isEmpty {
            guard !isEdit else { return .failure(.missingFields) }
            totalValue = 0
        } else {
            guard let value = number(totalText, maxDigits: maxTotalDigits) else { return .failure(.missingFields) }
            totalValue = value
        }
        return .success(Output(name: trimmedName, loopSize: loop, total: totalValue))
    }

    /// Keeps only ASCII digits (also converts Arabic-Indic digits typed on an Arabic keyboard).
    static func digitsOnly(_ text: String, maxDigits: Int) -> String {
        let converted = text.compactMap { character -> Character? in
            if character.isASCII, character.isNumber { return character }
            if let scalar = character.unicodeScalars.first, (0x0660...0x0669).contains(scalar.value) ||
                (0x06F0...0x06F9).contains(scalar.value) {
                let base: UInt32 = scalar.value >= 0x06F0 ? 0x06F0 : 0x0660
                return Character(String(scalar.value - base))
            }
            return nil
        }
        return String(converted.prefix(maxDigits))
    }

    private static func number(_ text: String, maxDigits: Int) -> Int? {
        guard text.count <= maxDigits, text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(text)
    }
}
