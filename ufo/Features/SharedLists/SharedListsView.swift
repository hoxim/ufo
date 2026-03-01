import SwiftUI
import SwiftData

struct SharedListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var listStore: SharedListStore?
    @State private var newListName = ""
    @State private var selectedType: SharedListType = .shopping
    @State private var newItemTextByList: [UUID: String] = [:]

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        NavigationStack {
            List {
                if let error = listStore?.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Section("New list") {
                    TextField("List name", text: $newListName)
                    Picker("Type", selection: $selectedType) {
                        ForEach(SharedListType.allCases) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    Button("Create list") {
                        Task {
                            await listStore?.addList(
                                name: newListName.trimmingCharacters(in: .whitespacesAndNewlines),
                                type: selectedType,
                                actor: authRepo.currentUser?.id
                            )
                            newListName = ""
                        }
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ForEach(listStore?.lists ?? []) { list in
                    Section(list.name) {
                        ForEach(listStore?.itemsByList[list.id] ?? []) { item in
                            HStack {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                                    .onTapGesture {
                                        Task { await listStore?.toggleItem(item, actor: authRepo.currentUser?.id) }
                                    }
                                Text(item.title)
                            }
                        }

                        HStack {
                            TextField("New item", text: bindingForItemInput(list.id))
                            Button {
                                Task {
                                    let value = newItemTextByList[list.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !value.isEmpty else { return }
                                    await listStore?.addItem(listId: list.id, title: value)
                                    newItemTextByList[list.id] = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shared Lists")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await listStore?.syncPending() }
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .task { await setupStoreIfNeeded() }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                listStore?.setSpace(newValue)
                Task { await listStore?.refreshRemote() }
            }
        }
    }

    private func bindingForItemInput(_ listId: UUID) -> Binding<String> {
        Binding {
            newItemTextByList[listId, default: ""]
        } set: {
            newItemTextByList[listId] = $0
        }
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard listStore == nil else { return }
        let repo = SharedListRepository(client: SupabaseConfig.client, context: modelContext)
        let store = SharedListStore(modelContext: modelContext, repository: repo)
        listStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if !isPreview {
            await store.refreshRemote()
        }
    }
}

#Preview("Shared Lists") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        SpaceInvitation.self,
        Mission.self,
        Incident.self,
        LinkedThing.self,
        Assignment.self,
        SharedList.self,
        SharedListItem.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    context.insert(user)
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))

    let shopping = SharedList(spaceId: space.id, name: "Weekend shopping", type: SharedListType.shopping.rawValue)
    context.insert(shopping)
    context.insert(SharedListItem(listId: shopping.id, title: "Milk", isCompleted: true, position: 1))
    context.insert(SharedListItem(listId: shopping.id, title: "Bread", isCompleted: false, position: 2))

    try? context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return SharedListsView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
