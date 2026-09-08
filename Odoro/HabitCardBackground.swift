import SwiftUI

struct HabitCardBackground: View {
    let tint: Color
    var cornerRadius: CGFloat = 16

    var body: some View {
        AppGlassBackground(shape: RoundedRectangle(cornerRadius: cornerRadius),
                           tint: tint.opacity(0.08), clear: true)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

/// Shared optical surface for cards and controls; content stays above the glass.
struct AppGlassBackground<Surface: InsettableShape>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let shape: Surface
    var tint: Color = .clear
    var clear = false
    var dimmed = false

    var body: some View {
        Group {
            if reduceTransparency {
                shape.fill(Color(white: 0.18))
            } else if #available(iOS 26.0, macOS 26.0, *) {
                Color.clear
                    .glassEffect((clear || dimmed ? Glass.clear : Glass.regular).tint(tint), in: shape)
            } else {
                shape.fill(.ultraThinMaterial)
                    .overlay { shape.fill(tint) }
                    .overlay {
                        shape.strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.04), .white.opacity(0.25)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    }
            }
        }
        .overlay {
            if dimmed && !reduceTransparency {
                // Keep the refracting edge but subdue bright waves beneath white text.
                shape.fill(.black.opacity(colorScheme == .light ? 0.68 : 0.5))
            }
        }
        .allowsHitTesting(false)
    }
}

enum FocusSurfaceRole {
    case tracker
    case picker
    case timer
}

/// A quieter, colored acrylic surface for controls that need strong contrast.
/// Light mode uses a soft pearl surface with dark ink; dark mode uses a deep
/// theme-colored surface with white ink.
struct FocusSurfaceBackground<Surface: InsettableShape>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(BackgroundTheme.storageKey) private var selectedTheme = BackgroundTheme.violet.rawValue

    let shape: Surface
    var role: FocusSurfaceRole = .timer
    var accent: Color? = nil

    private var palette: WavePalette {
        let theme = BackgroundTheme(rawValue: selectedTheme) ?? .violet
        return role == .tracker ? theme.trackerPalette(for: colorScheme) : theme.pickerPalette(for: colorScheme)
    }

    var body: some View {
        ZStack {
            shape.fill(.thinMaterial)

            if colorScheme == .light {
                shape.fill(Color.white.opacity(reduceTransparency ? 0.96 : 0.48))
                shape.fill(palette.middle.opacity(0.11))
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            palette.back.opacity(0.04),
                            palette.middle.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                shape.fill(
                    LinearGradient(
                        colors: [
                            palette.background.opacity(reduceTransparency ? 0.98 : 0.82),
                            palette.back.opacity(0.52),
                            Color.black.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }

            if let accent {
                shape.fill(accent.opacity(colorScheme == .light ? 0.08 : 0.22))
            }
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: colorScheme == .light
                        ? [.white.opacity(0.62), palette.middle.opacity(0.18)]
                        : [.white.opacity(0.24), palette.middle.opacity(0.42)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(colorScheme == .light ? 0.12 : 0.26), radius: 8, y: 4)
        .allowsHitTesting(false)
    }
}

enum FocusSurfaceStyle {
    static func textColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(red: 0.10, green: 0.12, blue: 0.17) : .white
    }

    static func secondaryTextColor(for colorScheme: ColorScheme) -> Color {
        textColor(for: colorScheme).opacity(0.68)
    }
}
