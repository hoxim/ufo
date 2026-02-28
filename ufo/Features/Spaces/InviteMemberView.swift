import SwiftUI

struct InviteMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SpaceRepository.self) private var spaceRepo

    let spaceId: UUID

    @State private var viewModel: InviteViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    InviteForm(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Invite to Crew")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InviteViewModel(
                    spaceRepository: spaceRepo,
                    spaceId: spaceId
                )
            }
        }
    }
}

struct InviteForm: View {
    @Bindable var vm: InviteViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter the email address of the new crew member.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("Ally's Email", text: $vm.email)
                #if os(iOS)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #else
                .textFieldStyle(.roundedBorder)
                #endif
            
            Button {
                Task {
                    await vm.sendInvite()
                }
            } label: {
                if vm.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Send Transmission")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.email.isEmpty || vm.isProcessing)
            
            Spacer()
        }
        .padding()
        .alert("Status", isPresented: $vm.showMessage) {
            Button("OK", role: .cancel) {
                if vm.isSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(vm.message ?? "")
        }
    }
}
