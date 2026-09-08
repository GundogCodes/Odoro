import SwiftUI

struct TimerPhaseColorsSection: View {
    let title: String
    let icon: String
    @Binding var fill: Color
    @Binding var background: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.white)
            ColorPicker("Fill", selection: $fill, supportsOpacity: false)
                .foregroundColor(.white.opacity(0.8))
                .accessibilityLabel("\(title) fill color")
            ColorPicker("Background", selection: $background, supportsOpacity: true)
                .foregroundColor(.white.opacity(0.8))
                .accessibilityLabel("\(title) background color")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
    }
}
