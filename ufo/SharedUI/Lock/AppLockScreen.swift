#if os(iOS)

import SwiftUI

struct AppLockScreen: View {
    @Environment(AppBiometricStore.self) private var biometricStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(hex: "#1A1A2E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    Text("lock.title")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("lock.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 16) {
                    if let error = biometricStore.authError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    Button {
                        Task { await biometricStore.authenticate() }
                    } label: {
                        HStack(spacing: 10) {
                            if biometricStore.isAuthenticating {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: biometricStore.biometrySystemImage)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            Text("lock.unlock")
                                .font(.body.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(biometricStore.isAuthenticating)
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 48)
            }
        }
        .task {
            await biometricStore.authenticate()
        }
    }
}

#Preview {
    AppLockScreen()
        .environment(AppBiometricStore())
}

#endif
