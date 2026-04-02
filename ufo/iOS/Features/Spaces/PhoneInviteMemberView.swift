import SwiftUI

struct PhoneInviteMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SpaceRepository.self) private var spaceRepo

    let space: Space

    @State private var viewModel: PhoneInviteViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if !space.allowsInvitations {
                    ContentUnavailableView(
                        "spaces.invite.unavailable.title",
                        systemImage: "lock.fill",
                        description: Text("spaces.invite.unavailable.description")
                    )
                } else if let vm = viewModel {
                    PhoneInviteForm(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("spaces.invite.title")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                if let vm = viewModel, space.allowsInvitations {
                    ModalConfirmToolbarItem(
                        isDisabled: vm.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isProcessing,
                        isProcessing: vm.isProcessing,
                        action: {
                            Task { await vm.sendInvite() }
                        }
                    )
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = PhoneInviteViewModel(
                    spaceRepository: spaceRepo,
                    spaceId: space.id
                )
            }
        }
    }
}

struct PhoneInviteForm: View {
    @Bindable var vm: PhoneInviteViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("spaces.invite.description")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("spaces.invite.field.email", text: $vm.email)
                .textFieldStyle(.roundedBorder)
                .emailKeyboardIfSupported()
                .autocorrectionDisabledIfSupported()
                .platformTextInputAutocapitalization(.never)

            Spacer()
        }
        .padding()
        
        .alert("common.status", isPresented: $vm.showMessage) {
            Button("common.ok", role: .cancel) {
                if vm.isSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(vm.message ?? "")
        }
    }
}

#Preview("Invite Allowed") {
    let repo = SpaceRepository(client: SupabaseConfig.client)
    let space = Space(id: UUID(), name: "Team Ops", inviteCode: "ABC123", category: SpaceType.shared.rawValue)
    PhoneInviteMemberView(space: space)
        .environment(repo)
}

#Preview("Invite Blocked") {
    let repo = SpaceRepository(client: SupabaseConfig.client)
    let space = Space(id: UUID(), name: "Personal", inviteCode: "ABC123", category: SpaceType.personal.rawValue)
    PhoneInviteMemberView(space: space)
        .environment(repo)
}
