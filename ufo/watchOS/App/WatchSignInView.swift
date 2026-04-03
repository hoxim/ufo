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

    @Environment(WatchAppModel.self) private var model

    @State private var email = ""
    @State private var password = ""
    @State private var selectedMethod: SignInMethod = .phone

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("UFO Watch")
                    .font(.headline)

                Text("Najwygodniej połączyć zegarek z już zalogowanym iPhonem.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(SignInMethod.allCases) { method in
                    Button {
                        withAnimation {
                            selectedMethod = method
                        }
                    } label: {
                        WatchSignInMethodCard(
                            title: method.title,
                            subtitle: method.subtitle,
                            icon: method.icon,
                            isSelected: selectedMethod == method
                        )
                    }
                    .buttonStyle(.plain)
                }

                signInDetailsSection

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle("Logowanie")
    }

    @ViewBuilder
    private var signInDetailsSection: some View {
        switch selectedMethod {
        case .phone:
            phoneSignInSection
        case .code:
            codePairingSection
        case .credentials:
            directSignInSection
        }
    }

    @ViewBuilder
    private var phoneSignInSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        }
    }

    @ViewBuilder
    private var codePairingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .buttonStyle(.bordered)
                .disabled(model.isAwaitingPhoneApproval)
            }
        }
    }

    @ViewBuilder
    private var directSignInSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .buttonStyle(.bordered)
            .disabled(email.isEmpty || password.isEmpty || model.isAwaitingPhoneApproval || model.isAwaitingCodeApproval)
        }
    }
}

private struct WatchSignInMethodCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
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
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#endif
