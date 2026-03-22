import SwiftUI

struct ModalCloseToolbarItem: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: action) {
                Image(systemName: "xmark")
            }
        }
    }
}

struct ModalConfirmToolbarItem: ToolbarContent {
    let isDisabled: Bool
    let isProcessing: Bool
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
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
