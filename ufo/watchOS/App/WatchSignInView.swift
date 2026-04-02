#if os(watchOS)
import SwiftUI

struct WatchSignInView: View {
    @Environment(WatchAppModel.self) private var model

    @State private var email = ""
    @State private var password = ""
    @State private var showCodePairing = false
    @State private var showDirectSignIn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("UFO Watch")
                    .font(.headline)

                Text("Najwygodniej połączyć zegarek z już zalogowanym iPhonem.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await model.connectToPhone()
                    }
                } label: {
                    Label("Połącz z iPhonem", systemImage: "iphone.gen3.radiowaves.left.and.right")
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

                Toggle(isOn: $showCodePairing.animation()) {
                    Text("Połącz kodem")
                        .font(.footnote)
                }

                if showCodePairing {
                    codePairingSection
                }

                Toggle(isOn: $showDirectSignIn.animation()) {
                    Text("Zaloguj bezpośrednio")
                        .font(.footnote)
                }

                if showDirectSignIn {
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
    private var codePairingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wygeneruj kod i zatwierdź go na iPhonie, iPadzie albo Macu w sekcji Urządzenia. Na iPhonie możesz też zeskanować QR.")
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
                    Label("Pokaż kod", systemImage: "number")
                }
                .buttonStyle(.bordered)
                .disabled(model.isAwaitingPhoneApproval)
            }
        }
    }
}

#endif
