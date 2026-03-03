import SwiftUI

struct OperationStylePicker: View {
    @Binding var iconName: String
    @Binding var colorHex: String

    private let icons = [
        "target", "checklist", "cart", "house", "bed.double", "books.vertical", "phone", "key", "camera", "map", "car", "bicycle", "airplane", "gamecontroller", "lightbulb", "leaf", "pawprint", "star"
    ]

    private let colors = [
        "#EC4899", "#EF4444", "#F97316", "#F59E0B", "#EAB308", "#22C55E", "#14B8A6", "#06B6D4", "#3B82F6", "#6366F1", "#8B5CF6", "#FFFFFF"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Style")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        iconName = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(Color(hex: colorHex))
                            .background(Color.white.opacity(iconName == icon ? 0.2 : 0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                ForEach(colors, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 26, height: 26)
                            .overlay {
                                if colorHex == hex {
                                    Circle().stroke(Color.white, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
