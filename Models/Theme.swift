import SwiftUI

// MARK: - Adaptive Color Helper

extension Color {
    /// Creates a color that automatically adapts to system light/dark appearance.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }
}

// MARK: - Semantic Design Tokens
// Cool, calm "focus time" palette — indigo primary on a warm near-neutral bg.

enum Theme {

    // ─── Core ───

    static let background = Color(
        light: Color(red: 0.980, green: 0.980, blue: 0.984),
        dark: Color(red: 0.106, green: 0.110, blue: 0.125)
    )
    static let foreground = Color(
        light: Color(red: 0.106, green: 0.118, blue: 0.149),
        dark: Color(red: 0.949, green: 0.953, blue: 0.961)
    )

    // ─── Card / Popover ───

    static let card = Color(
        light: Color.white,
        dark: Color(red: 0.149, green: 0.157, blue: 0.180)
    )
    static let cardForeground = Color(
        light: Color(red: 0.106, green: 0.118, blue: 0.149),
        dark: Color(red: 0.949, green: 0.953, blue: 0.961)
    )

    static let popover = card
    static let popoverForeground = cardForeground

    // ─── Primary (indigo) ───

    static let primary = Color(
        light: Color(red: 0.349, green: 0.380, blue: 0.922),
        dark: Color(red: 0.482, green: 0.533, blue: 0.988)
    )
    static let primaryForeground = Color(
        light: Color.white,
        dark: Color.white
    )

    // ─── Secondary / Muted / Accent ───

    static let secondary = Color(
        light: Color(red: 0.949, green: 0.949, blue: 0.961),
        dark: Color(red: 0.196, green: 0.204, blue: 0.231)
    )
    static let secondaryForeground = Color(
        light: Color(red: 0.133, green: 0.149, blue: 0.196),
        dark: Color(red: 0.878, green: 0.886, blue: 0.902)
    )

    static let muted = Color(
        light: Color(red: 0.961, green: 0.961, blue: 0.969),
        dark: Color(red: 0.169, green: 0.176, blue: 0.204)
    )
    static let mutedForeground = Color(
        light: Color(red: 0.447, green: 0.471, blue: 0.522),
        dark: Color(red: 0.624, green: 0.639, blue: 0.671)
    )

    static let accent = Color(
        light: Color(red: 0.925, green: 0.933, blue: 0.996),
        dark: Color(red: 0.227, green: 0.247, blue: 0.345)
    )
    static let accentForeground = Color(
        light: Color(red: 0.278, green: 0.314, blue: 0.827),
        dark: Color(red: 0.749, green: 0.780, blue: 0.988)
    )

    // ─── Destructive ───

    static let destructive = Color(
        light: Color(red: 0.863, green: 0.259, blue: 0.263),
        dark: Color(red: 0.937, green: 0.420, blue: 0.420)
    )

    // ─── Border / Input / Ring ───

    static let border = Color(
        light: Color(red: 0.902, green: 0.906, blue: 0.929),
        dark: Color(red: 0.239, green: 0.251, blue: 0.290)
    )
    static let input = border
    static let ring = primary

    // ─── Chart palette (for project bars) ───

    static let chart1 = Color(light: Color(red: 0.349, green: 0.380, blue: 0.922), dark: Color(red: 0.482, green: 0.533, blue: 0.988))
    static let chart2 = Color(light: Color(red: 0.055, green: 0.647, blue: 0.914), dark: Color(red: 0.306, green: 0.745, blue: 0.969))
    static let chart3 = Color(light: Color(red: 0.051, green: 0.725, blue: 0.592), dark: Color(red: 0.173, green: 0.851, blue: 0.722))
    static let chart4 = Color(light: Color(red: 0.976, green: 0.573, blue: 0.106), dark: Color(red: 0.988, green: 0.690, blue: 0.282))
    static let chart5 = Color(light: Color(red: 0.925, green: 0.341, blue: 0.537), dark: Color(red: 0.961, green: 0.478, blue: 0.643))

    static let chartPalette: [Color] = [chart1, chart2, chart3, chart4, chart5]

    // ─── Radius ───

    static let radiusSm: CGFloat = 4
    static let radiusMd: CGFloat = 6
    static let radiusLg: CGFloat = 10
    static let radiusXl: CGFloat = 14
}

// MARK: - View Modifiers

extension View {
    func pointerCursor() -> some View {
        self.onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    func plainButton() -> some View {
        self.buttonStyle(.plain).pointerCursor()
    }
}

// MARK: - Color helpers

extension Color {
    /// Stable palette pick for a project based on its name hash.
    static func paletteColor(for key: String) -> Color {
        let hash = abs(key.hashValue)
        return Theme.chartPalette[hash % Theme.chartPalette.count]
    }
}
