import Foundation

/// In-character writing prompts, chosen to fit what the writer has been feeling and who they're
/// close to. Selection is deterministic for a given context and seed so tests can pin it down and
/// "shuffle" just advances the seed.
enum WritingPrompts {
    static let enabledKey = "prompts.enabled"

    struct Context: Equatable {
        /// The writing character, or nil for the narrator.
        var name: String?
        /// Emotions from their most recent entries, most recent first.
        var recentEmotions: [Emotion] = []
        /// People they have the strongest feelings about, strongest first.
        var bondNames: [String] = []
        var place: String?
        var quest: String?
    }

    /// Placeholders: {name}, {other}, {place}, {quest}. A template is only used when every
    /// placeholder it contains can be filled.
    static let general = [
        "What did {name} notice today that no one else did?",
        "What is {name} carrying that they wish they could put down?",
        "Describe the last thing {name} ate, and who they shared it with.",
        "What would {name} never admit out loud?",
        "If {name} could send one letter home tonight, what would it say?",
        "What does {name} dream about when the fire burns low?",
        "What promise has {name} made that they're not sure they can keep?",
    ]

    static let byGroup: [EmotionGroup: [String]] = [
        .resolve: [
            "What keeps {name} walking forward when the road gets hard?",
            "Which victory is {name} proudest of, and what did it cost?",
        ],
        .fire: [
            "Who or what has lit {name}'s anger, and what will they do with it?",
            "What line is {name} tempted to cross?",
        ],
        .shadow: [
            "What does {name} fear most tonight?",
            "Who is {name} mourning, and what do they miss most?",
        ],
        .warmth: [
            "What small moment made {name} smile today?",
            "Where does {name} feel most at home on this journey?",
        ],
        .doubt: [
            "What question keeps {name} awake?",
            "Two paths lie ahead of {name}. What pulls them each way?",
        ],
    ]

    static let aboutSomeone = [
        "What does {name} really think of {other}?",
        "What would {name} want to tell {other} but can't?",
        "When did {name} last see {other} truly afraid?",
    ]

    static let aboutPlace = [
        "What does {place} smell like to {name}?",
        "What will {name} remember about {place} years from now?",
    ]

    static let aboutQuest = [
        "Why does {quest} matter to {name}, beyond the reward?",
        "What has {quest} already taken from {name}?",
    ]

    /// Every prompt that fits, in a stable order. Templates matching recent emotions come first
    /// and appear once per matching emotion, so they're picked more often.
    static func candidates(for context: Context) -> [String] {
        var templates: [String] = []
        for emotion in context.recentEmotions {
            templates += byGroup[emotion.group] ?? []
        }
        if !context.bondNames.isEmpty { templates += aboutSomeone }
        if context.place != nil { templates += aboutPlace }
        if context.quest != nil { templates += aboutQuest }
        templates += general
        return templates.compactMap { fill($0, with: context) }
    }

    /// The prompt for this context and seed. Different seeds walk through the candidates.
    static func prompt(for context: Context, seed: Int) -> String? {
        let options = candidates(for: context)
        guard !options.isEmpty else { return nil }
        let index = ((seed % options.count) + options.count) % options.count
        return options[index]
    }

    static func fill(_ template: String, with context: Context) -> String? {
        let name = context.name.flatMap { $0.isEmpty ? nil : $0 } ?? "the party"
        var result = template.replacingOccurrences(of: "{name}", with: name)
        let optional: [(String, String?)] = [
            ("{other}", context.bondNames.first),
            ("{place}", context.place.flatMap { $0.isEmpty ? nil : $0 }),
            ("{quest}", context.quest.flatMap { $0.isEmpty ? nil : $0 }),
        ]
        for (placeholder, value) in optional where result.contains(placeholder) {
            guard let value else { return nil }
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        // A template may start with a placeholder ("{quest} …"); capitalise the first letter.
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    /// Builds the context from the writer's recent entries and the notebook's latest whereabouts.
    static func context(for author: PartyMember?, in notebook: Notebook, recentCount: Int = 3) -> Context {
        let recent = author.map { Array($0.journal.prefix(recentCount)) } ?? Array(notebook.chronicle.prefix(recentCount))
        var seen = Set<Emotion>()
        let emotions = recent
            .flatMap { entry in entry.emotions.sorted { $0.intensity > $1.intensity }.compactMap(\.emotion) }
            .filter { seen.insert($0).inserted }
        let bonds = author.map { CharacterArc.bonds(in: $0.journal).map(\.name) } ?? []
        let latest = notebook.chronicle
        return Context(
            name: author?.name,
            recentEmotions: emotions,
            bondNames: bonds,
            place: latest.first { !$0.place.isEmpty }?.place,
            quest: latest.first { !$0.quest.isEmpty }?.quest
        )
    }
}
