#if os(iOS)

import SwiftUI
import Vision
import VisionKit

struct PhonePairingQRScannerSheet: View {
    let onPayloadScanned: (DevicePairingQRCodePayload) -> Void
    let onCancel: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    PhoneQRCodeScannerView { scannedString in
                        guard let payload = DevicePairingQRCodePayload(qrString: scannedString) else {
                            errorMessage = "To nie jest prawidłowy kod QR parowania UFO."
                            return
                        }

                        onPayloadScanned(payload)
                    }
                } else {
                    ContentUnavailableView(
                        "Skaner niedostępny",
                        systemImage: "camera.viewfinder",
                        description: Text("To urządzenie nie obsługuje skanowania QR z użyciem kamery.")
                    )
                }
            }
            .navigationTitle("Skanuj QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        onCancel()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.red, in: Capsule())
                        .padding()
                }
            }
        }
    }
}

private struct PhoneQRCodeScannerView: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator

        try? controller.startScanning()

        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScanned: (String) -> Void
        private var hasHandledScan = false

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            handle(addedItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            handle([item])
        }

        private func handle(_ items: [RecognizedItem]) {
            guard !hasHandledScan else { return }

            for item in items {
                guard case let .barcode(barcode) = item,
                      let payload = barcode.payloadStringValue
                else {
                    continue
                }

                hasHandledScan = true
                onScanned(payload)
                break
            }
        }
    }
}

#endif
