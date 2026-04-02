import SwiftUI

struct SelectionMenuRow<MenuContent: View>: View {
    let title: String
    let value: String
    var isPlaceholder: Bool = false
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Menu {
                menuContent()
            } label: {
                HStack(spacing: 4) {
                    Text(value)
                        .lineLimit(1)
                        .foregroundStyle(isPlaceholder ? .secondary : .primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .tint(.primary)
        }
    }
}
