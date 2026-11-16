import Foundation

/// Number formatting rules shared by every screen (≈ NumberFormatter.java on Android).
nonisolated enum NumberText {
    // Guarded by `lock`: NumberFormatter is not thread-safe.
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private static let lock = NSLock()

    /// ASCII digits with "," grouping, e.g. 1234 -> "1,234", in every language.
    static func grouped(_ value: Int) -> String {
        lock.lock()
        defer { lock.unlock() }
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Replaces ASCII digits with Arabic-Indic ones (٠١٢٣٤٥٦٧٨٩). Used only for the Arabic Hijri date.
    static func arabicIndicDigits(_ text: String) -> String {
        String(text.map { character -> Character in
            guard let digit = character.wholeNumberValue, character.isASCII,
                  let scalar = Unicode.Scalar(0x0660 + digit) else {
                return character
            }
            return Character(scalar)
        })
    }
}
