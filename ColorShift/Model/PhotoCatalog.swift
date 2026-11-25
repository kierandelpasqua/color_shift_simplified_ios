/// The 12 photos in **exactly** the web's order (`src/App.tsx` `photos`; ios.md I9). Share links use the
/// 0-based position here as `photo=N`, so never reorder, insert or remove without changing the web too.
/// Aspects are pixel width / height of the bundled files (T-014); photographers come from the web (docs/photo-sources.md).
/// `derived` pairs are the web's own `deriveFromPhoto` results, captured in Chrome (T-016; must equal
/// `ColorShiftTests/Fixtures/web-derived-pairs.json`). iOS uses them so colors match the web exactly.
nonisolated enum PhotoCatalog {
    static let all: [Photo] = [
        photo("photo-1500964757637-c85e8a162699", .outdoors, "Mountain ridges under a vivid pink and blue sky",
              derived: (bg: "#F2B356", fg: "#3B2A11"),
              bg: "#16172B", fg: "#F4C6D9", aspect: 2400 / 1543, "Simon Berger", "simon_berger"),
        photo("photo-1615729947596-a598e5de0ab3", .outdoors, "Green mountain ridge and yellow wildflowers",
              derived: (bg: "#C2B313", fg: "#FFFFFF"),
              bg: "#152D24", fg: "#F2D77D", aspect: 1600 / 2400, "Daniela Kokina", "danielakokina"),
        photo("photo-1787012055240-859e0bd53875", .urban, "Colorful apartment buildings in Hong Kong",
              derived: (bg: "#FCFEFF", fg: "#112D3B"),
              bg: "#222127", fg: "#F3A33C", aspect: 2400 / 1807, "Zoshua Colah", "zoshuacolah"),
        photo("photo-1787015163482-2e06e9091258", .urban, "Red van passing colorful residential buildings",
              derived: (bg: "#267A73", fg: "#E9F2FB"),
              bg: "#391B18", fg: "#FFD0A1", aspect: 1605 / 2400, "Zoshua Colah", "zoshuacolah"),
        photo("photo-1557053910-d9eadeed1c58", .people, "Portrait in a vivid red shirt",
              derived: (bg: "#9E1C08", fg: "#F6EACB"),
              bg: "#381018", fg: "#F8CFC6", aspect: 1600 / 2400, "Olena Bohovyk", "olenkasergienko"),
        photo("photo-1617690032703-f991ed0e0ee6", .people, "Portrait in pink and green with sunglasses",
              derived: (bg: "#00A95F", fg: "#FFFFFF"),
              bg: "#17352D", fg: "#FFB7D5", aspect: 1600 / 2400, "Brian Lawson", "visualartery"),
        photo("photo-1534599864649-c66531e112eb", .animals, "Iridescent green and blue bird feathers",
              derived: (bg: "#0F2C4A", fg: "#CFCBF6"),
              bg: "#102A32", fg: "#8FE1C1", aspect: 2400 / 1598, "Alexander Sinn", "swimstaralex"),
        photo("photo-1689758380989-f92c89619a2d", .animals, "Green and yellow chameleon in close-up",
              derived: (bg: "#097B6A", fg: "#E5F1FA"),
              bg: "#173423", fg: "#D9E66D", aspect: 1601 / 2400, "Rob Potter", "robpotter"),
        photo("photo-1550859492-d5da9d8e45f3", .abstract, "Soft rainbow color field",
              derived: (bg: "#0056B9", fg: "#D4CFF7"),
              bg: "#2C1836", fg: "#F4B8A5", aspect: 2400 / 1600, "Sean Sinclair", "seanwsinclair"),
        photo("photo-1548746450-48dbc4747adc", .abstract, "Flowing purple, red and warm orange shapes",
              derived: (bg: "#FC7B73", fg: "#FFFFFF"),
              bg: "#271531", fg: "#F1A45E", aspect: 1600 / 2400, "Marvin van Beek", "marvinvanbeek"),
        photo("photo-1760445798933-4d3945d0b06b", .objects, "Bowl of colorful objects and plants",
              derived: (bg: "#5F3402", fg: "#F1F6CB"),
              bg: "#21302A", fg: "#F3C9A6", aspect: 2400 / 1600, "Runda Choo", "rundachoo"),
        photo("photo-1558769673-de478227d1f5", .objects, "Headset, scissors and teapot arranged on a table",
              derived: (bg: "#00B29D", fg: "#FFFFFF"),
              bg: "#28231D", fg: "#E9C782", aspect: 1600 / 2400, "Alex Gruber", "alex_gruber"),
    ]

    /// Photos for a theme selection, in catalog order. An empty selection means All (PM §6).
    static func visible(for selectedThemes: Set<Theme>) -> [Photo] {
        selectedThemes.isEmpty ? all : all.filter { selectedThemes.contains($0.theme) }
    }

    /// The full-catalog index used in share links (never the filtered index; ios.md §14).
    static func catalogIndex(of photo: Photo) -> Int? {
        all.firstIndex { $0.id == photo.id }
    }

    private static func photo(
        _ id: String, _ theme: Theme, _ alt: String, derived: (bg: String, fg: String), bg: String, fg: String,
        aspect: Double, _ photographer: String, _ handle: String
    ) -> Photo {
        Photo(id: id, theme: theme, alt: alt,
              fallback: ColorPair(background: SRGB8(hex: bg)!, foreground: SRGB8(hex: fg)!),
              derived: ColorPair(background: SRGB8(hex: derived.bg)!, foreground: SRGB8(hex: derived.fg)!),
              aspect: aspect, photographer: photographer, handle: handle)
    }
}
