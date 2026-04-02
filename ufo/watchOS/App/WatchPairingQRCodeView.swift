#if os(watchOS)

import SwiftUI

struct WatchPairingQRCodeView: View {
    let payload: DevicePairingQRCodePayload
    private let borderModules = 3

    var body: some View {
        Group {
            if let qrCode {
                GeometryReader { geometry in
                    let side = min(geometry.size.width, geometry.size.height)
                    let moduleCount = qrCode.size + (borderModules * 2)
                    let moduleSize = side / CGFloat(moduleCount)

                    Canvas { context, _ in
                        context.fill(
                            Path(CGRect(origin: .zero, size: CGSize(width: side, height: side))),
                            with: .color(.white)
                        )

                        var path = Path()

                        for y in 0..<qrCode.size {
                            for x in 0..<qrCode.size where qrCode.getModule(x: x, y: y) {
                                path.addRect(
                                    CGRect(
                                        x: CGFloat(x + borderModules) * moduleSize,
                                        y: CGFloat(y + borderModules) * moduleSize,
                                        width: moduleSize,
                                        height: moduleSize
                                    )
                                )
                            }
                        }

                        context.fill(path, with: .color(.black))
                    }
                    .frame(width: side, height: side)
                }
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 132, height: 132)
    }

    private var qrCode: QRCode? {
        try? QRCode.encode(text: payload.qrString, ecl: .medium)
    }
}

#endif
