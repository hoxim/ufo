import SwiftUI
import SwiftData

struct LinksListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var linkStore: LinkStore?
    @State private var parentIdText = ""
    @State private var childIdText = ""

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        NavigationStack {
            List {
                if let error = linkStore?.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Section("Create Link") {
                    TextField("Parent UUID", text: $parentIdText)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Child UUID", text: $childIdText)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Button("Add Link") {
                        Task { await addLink() }
                    }
                }

                Section("Links") {
                    ForEach(linkStore?.links ?? []) { link in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Parent: \(link.parentId.uuidString)")
                                    .font(.caption)
                                Text("Child: \(link.childId.uuidString)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await linkStore?.deleteLink(link, actor: authRepo.currentUser?.id) }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Links")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await linkStore?.syncPending() }
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .task { await setupStoreIfNeeded() }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                linkStore?.setScope(newValue)
                Task { await linkStore?.refreshRemote() }
            }
        }
    }

    private func addLink() async {
        guard
            let parentId = UUID(uuidString: parentIdText.trimmingCharacters(in: .whitespacesAndNewlines)),
            let childId = UUID(uuidString: childIdText.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            linkStore?.lastErrorMessage = "Parent i Child muszą być poprawnymi UUID."
            return
        }

        await linkStore?.addLink(parentId: parentId, childId: childId, actor: authRepo.currentUser?.id)
        parentIdText = ""
        childIdText = ""
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard linkStore == nil else { return }
        let repo = LinkRepository(client: SupabaseConfig.client, context: modelContext)
        let store = LinkStore(modelContext: modelContext, repository: repo)
        linkStore = store
        store.setScope(spaceRepo.selectedSpace?.id)

        if !isPreview {
            await store.refreshRemote()
        }
    }
}

#Preview("Links") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        SpaceInvitation.self,
        Mission.self,
        Incident.self,
        LinkedThing.self,
        Assignment.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    context.insert(user)
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))
    context.insert(LinkedThing(thingId: space.id, parentId: UUID(), childId: UUID()))
    try? context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return LinksListView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
