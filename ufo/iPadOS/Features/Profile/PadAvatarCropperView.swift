#if os(iOS)

import SwiftUI
import UIKit

/// Presents an interactive avatar editor with drag, zoom and circular crop preview.
struct PadAvatarCropperView: View {
    let imageData: Data
    let onCancel: () -> Void
    let onSave: (Data) -> Void

    @State private var workingImage: UIImage?
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var errorMessage: String?
    @State private var cropViewportSide: CGFloat = 300

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 20
            let availableWidth = max(220, geometry.size.width - (horizontalPadding * 2))
            let cropSide = min(availableWidth, geometry.size.height * 0.58)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    topBar

                    cropEditor(cropSide: cropSide)
                        .onAppear {
                            cropViewportSide = cropSide
                        }
                        .onChange(of: cropSide) { _, newValue in
                            cropViewportSide = newValue
                        }

                    controls(cropSide: cropSide)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, max(geometry.safeAreaInsets.top, 12))
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .task {
                // Prepares the original image used by the editor.
                workingImage = UIImage(data: imageData)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button("common.cancel", action: onCancel)
                .font(.title3)

            Spacer()

            Button("common.done") {
                saveCroppedAvatar()
            }
            .font(.title3.weight(.semibold))
            .disabled(workingImage == nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
        .foregroundStyle(.white)
        .zIndex(2)
    }

    /// Renders the edit canvas with drag and pinch gestures.
    private func cropEditor(cropSide: CGFloat) -> some View {
        ZStack {
            if let workingImage {
                let baseScale = baseScaleForFill(image: workingImage, cropSide: cropSide)
                let effectiveScale = max(1, min(4, scale))
                let displayScale = baseScale * effectiveScale
                let imageSize = CGSize(
                    width: workingImage.size.width * displayScale,
                    height: workingImage.size.height * displayScale
                )

                Image(uiImage: workingImage)
                    .resizable()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .position(x: cropSide / 2 + dragOffset.width, y: cropSide / 2 + dragOffset.height)
                    .allowsHitTesting(false)
            }

            CircularCropOverlay()
                .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))

            Circle()
                .stroke(.white.opacity(0.95), lineWidth: 3)
                .padding(3)

            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard let workingImage else { return }
                            let baseScale = baseScaleForFill(image: workingImage, cropSide: cropSide)
                            let imageSize = CGSize(
                                width: workingImage.size.width * (baseScale * scale),
                                height: workingImage.size.height * (baseScale * scale)
                            )
                            let candidate = CGSize(
                                width: lastDragOffset.width + value.translation.width,
                                height: lastDragOffset.height + value.translation.height
                            )
                            dragOffset = clampedOffset(candidate, imageSize: imageSize, cropSide: cropSide)
                        }
                        .onEnded { _ in
                            lastDragOffset = dragOffset
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            guard let workingImage else { return }
                            let baseScale = baseScaleForFill(image: workingImage, cropSide: cropSide)
                            let candidate = max(1, min(4, lastScale * value))
                            scale = candidate
                            let imageSize = CGSize(
                                width: workingImage.size.width * (baseScale * candidate),
                                height: workingImage.size.height * (baseScale * candidate)
                            )
                            dragOffset = clampedOffset(dragOffset, imageSize: imageSize, cropSide: cropSide)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            lastDragOffset = dragOffset
                        }
                )
        }
        .frame(width: cropSide, height: cropSide)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .zIndex(1)
    }

    /// Shows editor actions and validation message.
    private func controls(cropSide: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    rotateImageClockwise()
                } label: {
                    Label("profile.avatarCropper.action.rotate", systemImage: "rotate.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button {
                    resetTransform()
                } label: {
                    Label("profile.avatarCropper.action.reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("profile.avatarCropper.hint.moveZoom")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("profile.avatarCropper.hint.export")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)

            imageMetadata
        }
        .frame(width: cropSide)
    }

    /// Displays input image dimensions/size and export constraints.
    private var imageMetadata: some View {
        VStack(spacing: 4) {
            HStack {
                Text("profile.avatarCropper.meta.input")
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(inputMetadataText)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .font(.caption2)

            HStack {
                Text("profile.avatarCropper.meta.output")
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("profile.avatarCropper.meta.outputValue")
                    .foregroundStyle(.white.opacity(0.9))
            }
            .font(.caption2)
        }
        .padding(.top, 2)
    }

    /// Computes the transform and exports a square 1024x1024 JPEG under 1 MB.
    private func saveCroppedAvatar() {
        guard let workingImage else { return }

        let maxBytes = 1_000_000
        var targetSize: CGFloat = 1024

        while targetSize >= 512 {
            let rendered = renderCroppedSquare(from: workingImage, outputSize: targetSize)
            if let data = jpegDataUnderLimit(from: rendered, maxBytes: maxBytes) {
                onSave(data)
                return
            }
            // If quality compression is not enough, reduce dimensions and retry.
            targetSize -= 128
        }

        errorMessage = String(localized: "profile.avatarCropper.error.tooLarge")
    }

    /// Rotates the working image by 90 degrees and resets editor transforms.
    private func rotateImageClockwise() {
        guard let image = workingImage else { return }
        let newSize = CGSize(width: image.size.height, height: image.size.width)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let rotated = renderer.image { context in
            context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.cgContext.rotate(by: .pi / 2)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
        }

        workingImage = rotated
        resetTransform()
    }

    /// Returns default position and zoom for a fresh crop setup.
    private func resetTransform() {
        dragOffset = .zero
        lastDragOffset = .zero
        scale = 1
        lastScale = 1
        errorMessage = nil
    }

    /// Calculates a base scale that always covers the full crop square.
    private func baseScaleForFill(image: UIImage, cropSide: CGFloat) -> CGFloat {
        max(cropSide / image.size.width, cropSide / image.size.height)
    }

    /// Creates a short metadata string for the selected source image.
    private var inputMetadataText: String {
        guard let image = workingImage else { return "-" }
        let width = Int(image.size.width.rounded())
        let height = Int(image.size.height.rounded())
        let kilobytes = Int((Double(imageData.count) / 1024.0).rounded())
        return "\(width)×\(height) px, \(kilobytes) KB"
    }

    /// Renders the current crop transform into a square bitmap.
    private func renderCroppedSquare(from image: UIImage, outputSize: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        let imageSize = image.size
        let baseScale = baseScaleForFill(image: image, cropSide: cropViewportSide)
        let displayScale = baseScale * scale
        let pointsToPixels = outputSize / max(cropViewportSide, 1)
        let drawSize = CGSize(width: imageSize.width * displayScale, height: imageSize.height * displayScale)
        let drawOrigin = CGPoint(
            x: (outputSize - (drawSize.width * pointsToPixels)) / 2 + dragOffset.width * pointsToPixels,
            y: (outputSize - (drawSize.height * pointsToPixels)) / 2 + dragOffset.height * pointsToPixels
        )

        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
            image.draw(
                in: CGRect(
                    origin: drawOrigin,
                    size: CGSize(width: drawSize.width * pointsToPixels, height: drawSize.height * pointsToPixels)
                )
            )
        }
    }

    /// Encodes UIImage to JPEG and keeps reducing quality until the byte limit is met.
    private func jpegDataUnderLimit(from image: UIImage, maxBytes: Int) -> Data? {
        var quality: CGFloat = 0.9
        var jpegData = image.jpegData(compressionQuality: quality)

        while let data = jpegData, data.count > maxBytes, quality > 0.3 {
            quality -= 0.05
            jpegData = image.jpegData(compressionQuality: quality)
        }

        guard let finalData = jpegData, finalData.count <= maxBytes else {
            return nil
        }
        return finalData
    }

    /// Keeps image movement inside safe bounds so empty space never appears in crop.
    private func clampedOffset(_ offset: CGSize, imageSize: CGSize, cropSide: CGFloat) -> CGSize {
        let maxX = max(0, (imageSize.width - cropSide) / 2)
        let maxY = max(0, (imageSize.height - cropSide) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }
}

/// Draws a dark overlay with circular transparent hole.
private struct CircularCropOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addEllipse(in: rect.insetBy(dx: 6, dy: 6))
        return path
    }
}

#Preview("Avatar Cropper") {
    let image = UIImage(systemName: "person.fill")!
    let data = image.jpegData(compressionQuality: 1) ?? Data()
    PadAvatarCropperView(imageData: data, onCancel: {}, onSave: { _ in })
}

#endif
