#if os(watchOS)
import SwiftUI

struct WatchSignInView: View {
    private enum SignInMethod: String, CaseIterable, Identifiable {
        case phone
        case code
        case credentials

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .phone:
                return "watch.auth.method.phone.title"
            case .code:
                return "watch.auth.method.code.title"
            case .credentials:
                return "watch.auth.method.credentials.title"
            }
        }

        var subtitleKey: String {
            switch self {
            case .phone:
                return "watch.auth.method.phone.subtitle"
            case .code:
                return "watch.auth.method.code.subtitle"
            case .credentials:
                return "watch.auth.method.credentials.subtitle"
            }
        }

        var icon: String {
            switch self {
            case .phone:
                return "iphone.gen3.radiowaves.left.and.right"
            case .code:
                return "qrcode"
            case .credentials:
                return "person.crop.circle.badge.checkmark"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("watch.auth.heading")
                    .font(.headline)

                Text("watch.auth.intro")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(SignInMethod.allCases) { method in
                    NavigationLink {
                        destination(for: method)
                    } label: {
                        WatchSignInMethodCard(
                            titleKey: method.titleKey,
                            subtitleKey: method.subtitleKey,
                            icon: method.icon
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("watch.auth.title")
    }

    @ViewBuilder
    private func destination(for method: SignInMethod) -> some View {
        switch method {
        case .phone:
            WatchPhoneSignInScreen()
        case .code:
            WatchCodeSignInScreen()
        case .credentials:
            WatchCredentialsSignInScreen()
        }
    }
}

private struct WatchPhoneSignInScreen: View {
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("watch.auth.phone.description")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await model.connectToPhone()
                    }
                } label: {
                    Label("watch.auth.phone.action", systemImage: "iphone.gen3.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isAwaitingPhoneApproval || model.isAwaitingCodeApproval)

                if model.isAwaitingPhoneApproval {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView()
                        Text("watch.auth.phone.pending")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle("watch.auth.phone.navigationTitle")
    }
}

private struct WatchCodeSignInScreen: View {
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("watch.auth.code.description")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let qrPayload = model.pairingQRCodePayload {
                    HStack {
                        Spacer()
                        WatchPairingQRCodeView(payload: qrPayload)
                        Spacer()
                    }
                }

                if let pairingCode = model.pairingCode {
                    Text(pairingCode)
                        .font(.title3.monospacedDigit().bold())

                    if let expiresAt = model.pairingCodeExpiresAt {
                        Text(String(
                            format: String(localized: "watch.auth.code.expiresAt"),
                            expiresAt.formatted(date: .omitted, time: .shortened)
                        ))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if model.isAwaitingCodeApproval {
                    ProgressView()

                    Button("common.cancel") {
                        model.cancelCodePairing()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        Task {
                            await model.startCodePairing()
                        }
                    } label: {
                        Label("watch.auth.code.action", systemImage: "qrcode")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isAwaitingPhoneApproval)
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle("watch.auth.code.navigationTitle")
    }
}

private struct WatchCredentialsSignInScreen: View {
    @Environment(WatchAppModel.self) private var model

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("watch.auth.credentials.description")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("auth.login.email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("auth.login.password", text: $password)

                Button {
                    Task {
                        await model.signIn(email: email, password: password)
                    }
                } label: {
                    Label("auth.login.button", systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || model.isAwaitingPhoneApproval || model.isAwaitingCodeApproval)

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle("watch.auth.credentials.navigationTitle")
    }
}

private struct WatchSignInMethodCard: View {
    let titleKey: String
    let subtitleKey: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey)
                        .font(.headline)
                        .multilineTextAlignment(.leading)

                    Text(subtitleKey)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#endif
