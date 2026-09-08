import SwiftUI

struct WavePalette {
    let background: Color
    let back: Color
    let middle: Color
    let front: Color

    init(_ background: UInt32, _ back: UInt32, _ middle: UInt32, _ front: UInt32) {
        func color(_ hex: UInt32) -> Color {
            Color(red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255)
        }
        self.background = color(background)
        self.back = color(back)
        self.middle = color(middle)
        self.front = color(front)
    }
}

enum BackgroundTheme: String, CaseIterable, Identifiable {
    case violet, rose, forest
    // Preserve saved choices from the earlier Ocean and Sunset themes.
    case frost = "ocean"
    case earth = "sunset"

    static let storageKey = "backgroundWaveTheme"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .violet: return "Classic Purple"
        case .rose: return "Royal Rose"
        case .forest: return "Forest Green"
        case .frost: return "Frosty Blue"
        case .earth: return "Earthy Brown"
        }
    }

    func trackerPalette(for scheme: ColorScheme) -> WavePalette {
        switch (self, scheme == .dark) {
        case (.violet, true): return WavePalette(0x1F1A40, 0x403380, 0x6640A6, 0x8C4DBF)
        case (.violet, false): return WavePalette(0x99B3E6, 0x668CD9, 0x8073CC, 0x9966BF)
        case (.rose, true): return WavePalette(0x2D1015, 0x5F1B27, 0x962B3C, 0xBF4D5B)
        case (.rose, false): return WavePalette(0xE3BABB, 0xC58487, 0xA9525B, 0x8C303E)
        case (.forest, true): return WavePalette(0x102A22, 0x204535, 0x326449, 0x548364)
        case (.forest, false): return WavePalette(0xC0CDB7, 0x8FA68A, 0x63836B, 0x466951)
        case (.frost, true): return WavePalette(0x182A3A, 0x344F68, 0x6D94B2, 0xBED7E7)
        case (.frost, false): return WavePalette(0xF2F8FC, 0xDDEBF5, 0xB9D5E9, 0x8DB8D7)
        case (.earth, true): return WavePalette(0x281D17, 0x49362A, 0x72533D, 0x9C7958)
        case (.earth, false): return WavePalette(0xDDD0BA, 0xBEA58A, 0x9A7B5C, 0x795B43)
        }
    }

    // Related shades distinguish the picker while keeping the same color family.
    // Classic Purple retains the original app's green/orange picker.
    func pickerPalette(for scheme: ColorScheme) -> WavePalette {
        switch (self, scheme == .dark) {
        case (.violet, true): return WavePalette(0x007366, 0x00B380, 0x1AD9A6, 0x33F299)
        case (.violet, false): return WavePalette(0xFFBF4D, 0xFF8C4D, 0xFF7366, 0xFF5980)
        case (.rose, true): return WavePalette(0x321414, 0x642225, 0x993F43, 0xBB6563)
        case (.rose, false): return WavePalette(0xE7C3BF, 0xCB9690, 0xAF665F, 0x954B49)
        case (.forest, true): return WavePalette(0x1B3024, 0x354E37, 0x56754C, 0x80946B)
        case (.forest, false): return WavePalette(0xD1D7BF, 0xA7B494, 0x819674, 0x617B59)
        case (.frost, true): return WavePalette(0x233142, 0x4A617C, 0x8AA6C3, 0xD4E4F2)
        case (.frost, false): return WavePalette(0xEBF2FA, 0xD0DFEF, 0xA6C1DF, 0x7EA3C9)
        case (.earth, true): return WavePalette(0x33241B, 0x594231, 0x85674D, 0xB49572)
        case (.earth, false): return WavePalette(0xE7D8C3, 0xCDB394, 0xAF8C68, 0x8C694B)
        }
    }
}

struct BackgroundThemePicker: View {
    @AppStorage(BackgroundTheme.storageKey) private var selectedTheme = BackgroundTheme.violet.rawValue

    private var currentTheme: BackgroundTheme {
        BackgroundTheme(rawValue: selectedTheme) ?? .violet
    }

    var body: some View {
        Menu {
            ForEach(BackgroundTheme.allCases) { theme in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                        selectedTheme = theme.rawValue
                    }
                } label: {
                    Label(theme.title,
                          systemImage: selectedTheme == theme.rawValue ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            ThemeButtonSwatch(theme: currentTheme)
                .frame(width: 34, height: 36)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(ThemeButtonStyle())
        .accessibilityLabel("Theme: \(currentTheme.title)")
        .accessibilityHint("Opens the background theme menu")
    }
}

private struct ThemeButtonSwatch: View {
    let theme: BackgroundTheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        ZStack {
            shape.fill(theme.trackerPalette(for: .dark).background)
                .offset(y: 3)
            shape.fill(theme.trackerPalette(for: .light).middle)
            ThemeButtonWave()
                .fill(theme.trackerPalette(for: .dark).middle)
                .clipShape(shape)
        }
        .overlay { shape.strokeBorder(.white.opacity(0.9), lineWidth: 2) }
        .modifier(TrackerHeaderShadow())
    }
}

private struct ThemeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

private struct ThemeButtonWave: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height * 0.55))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.5),
                          control1: CGPoint(x: rect.width * 0.4, y: rect.height * 0.12),
                          control2: CGPoint(x: rect.width * 0.55, y: rect.height * 0.88))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct TrackerHeaderShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.46), radius: 1, x: 0, y: 2)
            .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 4)
    }
}

/// Frost's pale daytime waves need dark headings outside the glass panels.
struct ThemeHeadingStyle: ViewModifier {
    @AppStorage(BackgroundTheme.storageKey) private var selectedTheme = BackgroundTheme.violet.rawValue
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundColor(selectedTheme == BackgroundTheme.frost.rawValue && colorScheme == .light
                                ? Color(red: 0.16, green: 0.25, blue: 0.36) : .white)
    }
}
