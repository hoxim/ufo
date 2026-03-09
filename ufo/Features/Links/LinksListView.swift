import SwiftUI
import SwiftData

struct LinksListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var linkStore: LinkStore?
    @State private var parentIdText = ""
    @State private var childIdText = ""
    @State private var viewingLink: LinkedThing?

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        NavigationStack {
            List {
                if let error = linkStore?.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Section("links.view.section.create") {
                    TextField("links.view.field.parentUuid", text: $parentIdText)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("links.view.field.childUuid", text: $childIdText)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Button("links.view.action.add") {
                        Task { await addLink() }
                    }
                }

                Section("links.view.section.items") {
                    ForEach(linkStore?.links ?? []) { link in
                        HStack {
                            Button {
                                viewingLink = link
                            } label: {
                                VStack(alignment: .leading) {
                                    Text("Parent: \(link.parentId.uuidString)")
                                        .font(.caption)
                                    Text("Child: \(link.childId.uuidString)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
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
            .navigationTitle("links.view.title")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await linkStore?.syncPending() }
                    } label: {
                        Label("common.sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .task { await setupStoreIfNeeded() }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                linkStore?.setScope(newValue)
                Task { await linkStore?.refreshRemote() }
            }
            .sheet(item: $viewingLink) { link in
                LinkDetailView(link: link)
            }
        }
    }

    /// Handles add link.
    private func addLink() async {
        guard
            let parentId = UUID(uuidString: parentIdText.trimmingCharacters(in: .whitespacesAndNewlines)),
            let childId = UUID(uuidString: childIdText.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            linkStore?.lastErrorMessage = String(localized: "links.view.error.invalidUuid")
            return
        }

        await linkStore?.addLink(parentId: parentId, childId: childId, actor: authRepo.currentUser?.id)
        parentIdText = ""
        childIdText = ""
    }

    @MainActor
    /// Sets up store if needed.
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

private struct LinkDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let link: LinkedThing

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("ID", value: link.id.uuidString)
                LabeledContent("Parent", value: link.parentId.uuidString)
                LabeledContent("Child", value: link.childId.uuidString)
                LabeledContent("Updated", value: link.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .navigationTitle("Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }
}

#Preview("links.view.section.items") {
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
    do {
        try context.save()
    } catch {
        Log.dbError("Links preview context.save", error)
    }

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return LinksListView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
