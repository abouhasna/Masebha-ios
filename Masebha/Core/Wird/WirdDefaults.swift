import Foundation

/// The wirds added the first time a supporter opens the Wird tab (≈ WirdDefaults + WirdDefaultData).
///
/// - "My Azkar": a copy of the user's current adhkar (text and loop size as the target).
/// - Five wirds from Hisn al-Muslim (hesnalmuslim.com): morning, evening, sleep, waking up, after
///   prayer. Their names and texts are Arabic in both languages. `WirdDefaults.json` is generated
///   from the Android `WirdDefaultData.java`, so both apps add exactly the same texts.
nonisolated enum WirdDefaults {
    private struct Entry: Decodable {
        let name: String
        let items: [Item]

        struct Item: Decodable {
            let target: Int
            let body: String
        }
    }

    /// The five built-in wirds, in order.
    static func builtIn(bundle: Bundle = .main) throws -> [NewWird] {
        guard let url = bundle.url(forResource: "WirdDefaults", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
        return entries.map { entry in
            NewWird(name: entry.name, items: entry.items.map { WirdDraft(body: $0.body, target: $0.target) })
        }
    }

    /// "My Azkar": the user's adhkar as a wird (empty names or loop sizes are skipped). Nil if
    /// nothing is left.
    static func myAzkar(named name: String, from adhkar: [Dhikr]) -> NewWird? {
        let items = adhkar.compactMap { dhikr -> WirdDraft? in
            let text = dhikr.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, dhikr.loopSize > 0 else { return nil }
            return WirdDraft(body: text, target: min(dhikr.loopSize, WirdStore.maximumTarget))
        }
        return items.isEmpty ? nil : NewWird(name: name, items: items)
    }
}
