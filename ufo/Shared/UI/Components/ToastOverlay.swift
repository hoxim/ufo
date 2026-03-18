import SwiftUI

struct ToastOverlay: View {
    let toast: AppToast
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: toast.style.symbolName)
                    .font(.title3)
                    .foregroundStyle(iconColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(toast.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let message = toast.message, !message.isEmpty {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var iconColor: Color {
        switch toast.style {
        case .success:
            return .green
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private var borderColor: Color {
        iconColor.opacity(0.35)
    }
}
