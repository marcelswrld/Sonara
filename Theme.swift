import SwiftUI

// =====================================================================
// Theme — single source of truth for the unified app's look.
// Direction: "the studio and the term sheet." Deep ink room, mint for
// what's alive (music, growth), brass strictly for money surfaces.
// Full rationale: 04-docs/DESIGN_DIRECTION.md
// =====================================================================

enum Theme {

    // MARK: Palette
    enum Palette {
        static let ink      = Color(hex: 0x070C13) // app background
        static let panel    = Color(hex: 0x0F1722) // raised surfaces
        static let hairline = Color(hex: 0x22303F) // borders, dividers
        static let chalk    = Color(hex: 0xF2F6FA) // primary text
        static let mist     = Color(hex: 0x94A6B8) // secondary text
        static let mint     = Color(hex: 0x3DE8C6) // brand accent — live, music
        static let brass    = Color(hex: 0xD9B25C) // money accent — valuation only
    }

    // MARK: Type
    // System faces so the scaffold builds with zero bundled assets.
    // Numbers always use monospaced digits so figures don't jitter.
    enum Type_ {
        static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func money(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
            .system(size: size, weight: weight, design: .rounded).monospacedDigit()
        }
        static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }
        static func caption(_ size: CGFloat = 12) -> Font {
            .system(size: size, weight: .medium).monospacedDigit()
        }
    }

    // MARK: Spacing scale
    enum Space {
        static let xs: CGFloat = 4
        static let s:  CGFloat = 8
        static let m:  CGFloat = 16
        static let l:  CGFloat = 24
        static let xl: CGFloat = 32
    }

    static let cornerRadius: CGFloat = 20

    // MARK: Gradients
    static let mintGlow = LinearGradient(
        colors: [Palette.mint.opacity(0.9), Palette.mint.opacity(0.4)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let brassGlow = LinearGradient(
        colors: [Palette.brass, Palette.brass.opacity(0.55)],
        startPoint: .top, endPoint: .bottom)

    static let cardWash = LinearGradient(
        colors: [Color.black.opacity(0.0), Color.black.opacity(0.75)],
        startPoint: .center, endPoint: .bottom)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255
        )
    }
}
