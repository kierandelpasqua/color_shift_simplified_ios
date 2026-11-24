/// Photo themes, in the web's chip order (PM §9). "All" is not a theme: it means no theme is selected.
nonisolated enum Theme: String, CaseIterable, Hashable, Sendable, Codable {
    case outdoors = "Outdoors"
    case urban = "Urban"
    case people = "People"
    case animals = "Animals"
    case abstract = "Abstract"
    case objects = "Objects"

    var title: String { rawValue }
}
