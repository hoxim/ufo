#if os(iOS)

import SwiftUI
import SwiftData

struct PhoneMessagesScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var messageStore: MessageStore?
    @State private var messageText = ""
    @State private var recipients: [SpaceMemberRecipient] = []
    @State private var selectedRecipientIds: Set<UUID> = []
    @State private var showRecipientsSheet = false

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        VStack(spacing: 8) {
                if let error = messageStore?.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                ScrollViewReader { proxy in
                    List {
                        ForEach(visibleMessages) { message in
                            HStack {
                                if message.senderId == authRepo.currentUser?.id {
                                    Spacer()
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(message.senderName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(message.body)
                                        .padding(10)
                                        .background(message.senderId == authRepo.currentUser?.id ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                                    if !message.recipientIds.isEmpty {
                                        Text("\(String(localized: "messages.view.toPrefix")) \(recipientNames(for: message.recipientIds).joined(separator: ", "))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .id(message.id)

                                if message.senderId != authRepo.currentUser?.id {
                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .appPrimaryListChrome()
                    .refreshable {
                        await refreshMessages()
                    }
                    .onChange(of: messageStore?.messages.count) { _, _ in
                        if let lastId = messageStore?.messages.last?.id {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                }

                HStack {
                    TextField("messages.view.field.body", text: $messageText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        showRecipientsSheet = true
                    } label: {
                        Image(systemName: "person.2")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await sendMessage() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
        }
        .appScreenBackground()
        .navigationTitle("messages.view.title")
        .hideTabBarIfSupported()
        .task { await setupStoreIfNeeded() }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            messageStore?.setSpace(newValue)
            Task {
                await messageStore?.refreshRemote()
                await loadRecipients()
            }
        }
        .sheet(isPresented: $showRecipientsSheet) {
            NavigationStack {
                List(recipients) { recipient in
                    Button {
                        toggleRecipient(recipient.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(recipient.displayName)
                                Text(recipient.role.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedRecipientIds.contains(recipient.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .navigationTitle("messages.recipients.title")
                .modalInlineTitleDisplayMode()
                .toolbar {
                    ModalCloseToolbarItem { showRecipientsSheet = false }
                }
            }
        }
    }

    /// Handles send message.
    private func sendMessage() async {
        guard
            let currentUser = authRepo.currentUser
        else {
            messageStore?.lastErrorMessage = String(localized: "messages.error.noUser")
            return
        }

        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let recipientIds = selectedRecipientIds.isEmpty
            ? Set(recipients.map(\.id).filter { $0 != currentUser.id })
            : selectedRecipientIds

        await messageStore?.sendMessage(
            body: trimmed,
            senderId: currentUser.id,
            senderName: currentUser.fullName ?? currentUser.email,
            recipientIds: Array(recipientIds)
        )
        messageText = ""
    }

    @MainActor
    /// Sets up store if needed.
    private func setupStoreIfNeeded() async {
        guard messageStore == nil else { return }
        let repo = MessageRepository(client: SupabaseConfig.client, context: modelContext)
        let store = MessageStore(modelContext: modelContext, repository: repo)
        messageStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if !isPreview {
            await loadRecipients()
            await store.refreshRemote()
        } else if let currentUser = authRepo.currentUser {
            recipients = [
                SpaceMemberRecipient(
                    id: currentUser.id,
                    email: currentUser.email,
                    fullName: currentUser.fullName,
                    avatarURL: currentUser.avatarURL,
                    providerAvatarURL: currentUser.providerAvatarURL,
                    role: currentUser.role
                )
            ]
        }
    }

    @MainActor
    private func refreshMessages() async {
        await messageStore?.syncPending()
        await loadRecipients()
        await messageStore?.refreshRemote()
    }

    @MainActor
    /// Loads recipients.
    private func loadRecipients() async {
        guard let spaceId = spaceRepo.selectedSpace?.id else {
            recipients = []
            selectedRecipientIds = []
            return
        }

        do {
            let members = try await spaceRepo.fetchRecipients(spaceId: spaceId)
            recipients = members
            if let currentUserId = authRepo.currentUser?.id, selectedRecipientIds.isEmpty {
                selectedRecipientIds = Set(members.filter { $0.id != currentUserId }.map(\.id))
            }
        } catch {
            recipients = []
            selectedRecipientIds = []
            messageStore?.lastErrorMessage = "\(String(localized: "messages.error.loadRecipientsPrefix")) \(error)"
        }
    }

    /// Toggles recipient.
    private func toggleRecipient(_ id: UUID) {
        if selectedRecipientIds.contains(id) {
            selectedRecipientIds.remove(id)
        } else {
            selectedRecipientIds.insert(id)
        }
    }

    /// Handles recipient names.
    private func recipientNames(for ids: [UUID]) -> [String] {
        let map = Dictionary(uniqueKeysWithValues: recipients.map { ($0.id, $0.displayName) })
        return ids.compactMap { map[$0] }
    }

    private var visibleMessages: [SpaceMessage] {
        guard let currentUserId = authRepo.currentUser?.id else {
            return messageStore?.messages ?? []
        }
        return (messageStore?.messages ?? []).filter { message in
            message.senderId == currentUserId
            || message.recipientIds.isEmpty
            || message.recipientIds.contains(currentUserId)
        }
    }
}

#Preview("Messages") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        SpaceInvitation.self,
        Mission.self,
        Incident.self,
        LinkedThing.self,
        Assignment.self,
        SpaceMessage.self
    ])

    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let parent = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Parent", role: "admin")
    let child = UserProfile(id: UUID(), email: "child@ufo.app", fullName: "Child", role: "child")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")

    context.insert(parent)
    context.insert(child)
    context.insert(space)
    context.insert(SpaceMembership(user: parent, space: space, role: "admin"))
    context.insert(SpaceMembership(user: child, space: space, role: "child"))
    context.insert(SpaceMessage(spaceId: space.id, senderId: parent.id, senderName: "Parent", body: "When will you be home?", recipientIds: [child.id]))
    context.insert(SpaceMessage(spaceId: space.id, senderId: child.id, senderName: "Child", body: "In 15 minutes", recipientIds: [parent.id]))

    do {
        try context.save()
    } catch {
        Log.dbError("Messages preview context.save", error)
    }

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: parent)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return PhoneMessagesScreen()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}

#endif
