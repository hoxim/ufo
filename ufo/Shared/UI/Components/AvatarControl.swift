//
//  Untitled.swift
//  ufo
//
//  Created by Marcin Ryzko on 22/02/2026.
//

import SwiftUI
import PhotosUI

enum AvatarSize {
    case small
    case medium
    case large
    
    var value: CGFloat {
        switch self {
        case .small: return 48
        case .medium: return 64
        case .large: return 128
        }
    }
}

struct AvatarControl: View {
    
    let avatarURL: String?
    let isEditable: Bool
    let size: AvatarSize
    let onAvatarUpdate: ((Data) -> Void)?
    
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    var body: some View {
        if isEditable {
            PhotosPicker(
                selection: self.$selectedImage,
                matching: .images
            ){
                avatarView
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                Task{
                    if let data = try? await newValue?.loadTransferable(type: Data.self){
                        onAvatarUpdate?(data)
                    }
                }
            }
        }
        else{
            avatarView
        }
        
    }
    
    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            if let avatarURL, !avatarURL.isEmpty {
                AsyncImage(url: URL(string:avatarURL)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "person.circle.fill") // Fallback
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: size.value, height: size.value)
                .clipShape(Circle())
            } else {
                Image("default-avatar")
                    .resizable()
                    .border(Color.gray, width: 1)
                    .frame(width: size.value, height: size.value)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.5), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            if isEditable {
                Image(systemName: "camera.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(6)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 3)
                    .offset(x: 12, y: 12)
                
            }
        }
    }
}

#Preview {
    AvatarControl(
        avatarURL: "https://www.gravatar.com/avatar/2c7d99fe281ecd3bcd65ab915bac6dd5",
        isEditable: true,
        size: .small,
        onAvatarUpdate: nil)
}
