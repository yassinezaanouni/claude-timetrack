import Foundation
import SwiftUI

/// Which dataset the UI is currently visualizing.
enum TrackingSource: String, CaseIterable, Identifiable, Codable {
    case claude
    case git

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claude: return "Claude"
        case .git:    return "Git"
        }
    }

    /// SF Symbol name for sources that don't have a custom asset.
    var sfSymbol: String? {
        switch self {
        case .claude: return nil
        case .git:    return "arrow.triangle.branch"
        }
    }

    /// Bundled image asset name (template-rendered) for sources with a brand mark.
    var customAsset: String? {
        switch self {
        case .claude: return "ClaudeMark"
        case .git:    return nil
        }
    }
}

/// Renders the icon for a `TrackingSource`, transparently handling both
/// SF Symbols (Git's branch glyph) and the bundled Claude brand mark.
struct SourceIcon: View {
    let source: TrackingSource
    let size: CGFloat
    var weight: Font.Weight = .semibold

    var body: some View {
        Group {
            if let asset = source.customAsset, let nsImage = Self.loadTemplate(named: asset) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else if let sym = source.sfSymbol {
                Image(systemName: sym)
                    .font(.system(size: size, weight: weight))
            }
        }
    }

    /// Loads a PNG from the SwiftPM resource bundle and marks it as a template
    /// image so AppKit tints it with the current foreground color. Cached on
    /// first hit since NSImage objects are immutable here.
    private static func loadTemplate(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
              let img = NSImage(contentsOf: url)
        else { return nil }
        img.isTemplate = true
        cache[name] = img
        return img
    }

    private static var cache: [String: NSImage] = [:]
}
