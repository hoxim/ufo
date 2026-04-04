#if os(watchOS)
import SwiftUI

struct WatchSignInView: View {
    private enum SignInMethod: String, CaseIterable, Identifiable {
        case phone
        case code
        case credentials

        var id: String { rawValue }

        var title: String {
            switch self {
            case .phone:
                return "Zaloguj przez iPhone'a"
            case .code:
                return "Zaloguj kodem lub QR"
            case .credentials:
                return "Zaloguj loginem i hasłem"
            }
        }

        var subtitle: String {
            switch self {
            case .phone:
                return "Najszybsza opcja. Zatwierdzasz logowanie w UFO na sparowanym iPhonie."
            case .code:
                return "Wygeneruj kod na zegarku i zatwierdź go na iPhonie, iPadzie albo Macu."
            case .credentials:
                return "Wpisz dane konta bezpośrednio na zegarku."
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
                Text("UFO Watch")
                    .font(.headline)

                Text("Najwygodniej połączyć zegarek z już zalogowanym iPhonem.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(SignInMethod.allCases) { method in
                    NavigationLink {
                        destination(for: method)
                    } label: {
                        WatchSignInMethodCard(
                            title: method.title,
                            subtitle: method.subtitle,
                            icon: method.icon
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Logowanie")
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
                Text("Użyj tej opcji, jeśli UFO jest już zalogowane na sparowanym iPhonie. Otwórz aplikację UFO na telefonie, a potem zatwierdź prośbę w sekcji Urządzenia.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await model.connectToPhone()
                    }
                } label: {
                    Label("Poproś iPhone'a o logowanie", systemImage: "iphone.gen3.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isAwaitingPhoneApproval || model.isAwaitingCodeApproval)

                if model.isAwaitingPhoneApproval {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView()
                        Text("Otwórz UFO na iPhonie i zatwierdź prośbę o połączenie.")
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
        .navigationTitle("Przez iPhone'a")
    }
}

private struct WatchCodeSignInScreen: View {
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Wygeneruj jednorazowy kod lub QR na zegarku, a potem zatwierdź logowanie w sekcji Urządzenia na iPhonie, iPadzie albo Macu.")
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
                        Text("Ważny do \(expiresAt.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if model.isAwaitingCodeApproval {
                    ProgressView()

                    Button("Anuluj") {
                        model.cancelCodePairing()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        Task {
                            await model.startCodePairing()
                        }
                    } label: {
                        Label("Wygeneruj kod i QR", systemImage: "qrcode")
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
        .navigationTitle("Kod lub QR")
    }
}

private struct WatchCredentialsSignInScreen: View {
    @Environment(WatchAppModel.self) private var model

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ta opcja nie wymaga iPhone'a ani kodu. Wpisz dane konta bezpośrednio na zegarku.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Hasło", text: $password)

                Button {
                    Task {
                        await model.signIn(email: email, password: password)
                    }
                } label: {
                    Label("Zaloguj", systemImage: "person.crop.circle.badge.checkmark")
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
        .navigationTitle("Login i hasło")
    }
}

private struct WatchSignInMethodCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
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
