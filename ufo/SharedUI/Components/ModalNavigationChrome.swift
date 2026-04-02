import SwiftUI

struct ModalCloseToolbarItem: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: closePlacement) {
            Button(action: action) {
                Image(systemName: "xmark")
            }
        }
    }

    private var closePlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .cancellationAction
        #else
        return .topBarLeading
        #endif
    }
}

struct ModalConfirmToolbarItem: ToolbarContent {
    let isDisabled: Bool
    let isProcessing: Bool
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: confirmPlacement) {
            Button(action: action) {
                if isProcessing {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark")
                }
            }
            .disabled(isDisabled)
        }
    }

    private var confirmPlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .confirmationAction
        #else
        return .topBarTrailing
        #endif
    }
}

extension View {
    @ViewBuilder
    func modalInlineTitleDisplayMode() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
