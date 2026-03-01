import SwiftUI

struct InviteMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SpaceRepository.self) private var spaceRepo

    let space: Space

    @State private var viewModel: InviteViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if !space.allowsInvitations {
                    ContentUnavailableView(
                        "To jest Private Space",
                        systemImage: "lock.fill",
                        description: Text("Aby zaprosić osoby, utwórz Space typu Shared.")
                    )
                } else if let vm = viewModel {
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
                    spaceId: space.id
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

#Preview("Invite Allowed") {
    let repo = SpaceRepository(client: SupabaseConfig.client)
    let space = Space(id: UUID(), name: "Team Ops", inviteCode: "ABC123", category: SpaceType.shared.rawValue)
    InviteMemberView(space: space)
        .environment(repo)
}

#Preview("Invite Blocked") {
    let repo = SpaceRepository(client: SupabaseConfig.client)
    let space = Space(id: UUID(), name: "Personal", inviteCode: "ABC123", category: SpaceType.personal.rawValue)
    InviteMemberView(space: space)
        .environment(repo)
}
