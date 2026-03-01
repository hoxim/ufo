import SwiftUI
import SwiftData
import PhotosUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MissionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var missionStore: MissionStore?
    @State private var isAddingMission = false
    @State private var editingMission: Mission?
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        NavigationStack {
            Group {
                if let missionStore {
                    content(store: missionStore)
                } else {
                    ProgressView("Loading Missions...")
                }
            }
            .navigationTitle("Active Missions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isAddingMission = true }) {
                        Label("Add Mission", systemImage: "plus")
                    }
                    .disabled(spaceRepo.selectedSpace == nil || missionStore == nil)
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await missionStore?.syncPending() }
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(missionStore?.isSyncing == true || spaceRepo.selectedSpace == nil)
                }
            }
            .sheet(isPresented: $isAddingMission) {
                if let missionStore {
                    AddMissionView(store: missionStore, userId: authRepo.currentUser?.id)
                        #if os(iOS)
                        .presentationDetents([.medium])
                        #endif
                        #if os(macOS)
                        .frame(minWidth: 520, minHeight: 420)
                        #endif
                }
            }
            .sheet(item: $editingMission) { mission in
                if let missionStore {
                    EditMissionView(
                        store: missionStore,
                        mission: mission,
                        userId: authRepo.currentUser?.id
                    )
                    #if os(iOS)
                    .presentationDetents([.medium])
                    #endif
                    #if os(macOS)
                    .frame(minWidth: 520, minHeight: 420)
                    #endif
                }
            }
            .task {
                await setupStoreIfNeeded()
            }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                guard let missionStore else { return }
                missionStore.setSpace(newValue)
                Task { await missionStore.refreshRemote() }
            }
        }
    }

    @ViewBuilder
    private func content(store: MissionStore) -> some View {
        List {
            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ForEach(store.missions) { mission in
                HStack {
                    if let iconName = mission.iconName, !iconName.isEmpty {
                        Image(systemName: iconName)
                            .foregroundStyle(.orange)
                    }
                    Image(systemName: mission.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(mission.isCompleted ? .green : .gray)
                        .onTapGesture {
                            Task {
                                await store.toggleCompleted(mission, userId: authRepo.currentUser?.id)
                            }
                        }

                    VStack(alignment: .leading) {
                        Text(mission.title).font(.headline)
                        if !mission.missionDescription.isEmpty {
                            Text(mission.missionDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if mission.imageData != nil {
                            Text("Image attached")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(0..<mission.difficulty, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }

                    Menu {
                        Button {
                            editingMission = mission
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task {
                                await store.deleteMission(mission, userId: authRepo.currentUser?.id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete { offsets in
                guard let store = missionStore else { return }
                let values = offsets.map { store.missions[$0] }
                Task {
                    for mission in values {
                        await store.deleteMission(mission, userId: authRepo.currentUser?.id)
                    }
                }
            }
        }
        .overlay {
            if store.isSyncing {
                ProgressView("Synchronizing...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard missionStore == nil else { return }

        let repo = MissionRepository(
            client: SupabaseConfig.client,
            context: modelContext
        )
        let store = MissionStore(
            modelContext: modelContext,
            missionRepository: repo
        )
        missionStore = store

        store.setSpace(spaceRepo.selectedSpace?.id)
        if !isPreview {
            await store.refreshRemote()
        }
    }
}

private struct EditMissionView: View {
    @Environment(\.dismiss) private var dismiss

    let store: MissionStore
    let mission: Mission
    let userId: UUID?

    @State private var title: String
    @State private var description: String
    @State private var difficulty: Int
    @State private var iconName: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false

    init(store: MissionStore, mission: Mission, userId: UUID?) {
        self.store = store
        self.mission = mission
        self.userId = userId
        _title = State(initialValue: mission.title)
        _description = State(initialValue: mission.missionDescription)
        _difficulty = State(initialValue: mission.difficulty)
        _iconName = State(initialValue: mission.iconName ?? "")
        _imageData = State(initialValue: mission.imageData)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Mission Title", text: $title)
                TextField("Briefing (Desc)", text: $description)
                TextField("Icon (SF Symbol)", text: $iconName)
                Stepper("Difficulty: \(difficulty)", value: $difficulty, in: 1...5)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Select image", systemImage: "photo")
                }
                if imageData != nil {
                    Text("Image selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save Changes")
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
            .navigationTitle("Edit Mission")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    imageData = try? await newValue.loadTransferable(type: Data.self)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        await store.updateMission(
            mission,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            difficulty: difficulty,
            iconName: iconName.isEmpty ? nil : iconName,
            imageData: imageData,
            userId: userId
        )
        dismiss()
    }
}

private struct AddMissionView: View {
    @Environment(\.dismiss) private var dismiss

    let store: MissionStore
    let userId: UUID?

    @State private var title = ""
    @State private var description = ""
    @State private var difficulty = 1
    @State private var iconName = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Mission Title", text: $title)
                TextField("Briefing (Desc)", text: $description)
                TextField("Icon (SF Symbol)", text: $iconName)
                Stepper("Difficulty: \(difficulty)", value: $difficulty, in: 1...5)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Select image", systemImage: "photo")
                }
                if imageData != nil {
                    Text("Image selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Deploy Mission")
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
            .navigationTitle("New Mission")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    imageData = try? await newValue.loadTransferable(type: Data.self)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        await store.addMission(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            difficulty: difficulty,
            iconName: iconName.isEmpty ? nil : iconName,
            imageData: imageData,
            userId: userId
        )
        dismiss()
    }
}

#Preview("Missions - Sample") {
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

    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let user = UserProfile(
        id: UUID(),
        email: "preview@ufo.app",
        fullName: "Preview User",
        role: "admin"
    )
    context.insert(user)

    let space = Space(
        id: UUID(),
        name: "Family Crew",
        inviteCode: "UFO123"
    )
    context.insert(space)

    let membership = SpaceMembership(user: user, space: space, role: "admin")
    context.insert(membership)

    let m1 = Mission(
        spaceId: space.id,
        title: "Buy groceries",
        missionDescription: "Milk, bread, eggs",
        difficulty: 2,
        createdBy: user.id
    )
    m1.isCompleted = false
    context.insert(m1)

    let m2 = Mission(
        spaceId: space.id,
        title: "Plan weekend trip",
        missionDescription: "Pick route and book hotel",
        difficulty: 3,
        createdBy: user.id
    )
    m2.isCompleted = true
    context.insert(m2)

    try? context.save()

    let authRepo = AuthRepository(
        client: SupabaseConfig.client,
        isLoggedIn: true,
        currentUser: user
    )
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return MissionsListView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
