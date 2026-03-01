import SwiftUI
import SwiftData
import PhotosUI

struct IncidentsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var incidentStore: IncidentStore?
    @State private var isAddingIncident = false
    @State private var editingIncident: Incident?
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        NavigationStack {
            Group {
                if let incidentStore {
                    content(store: incidentStore)
                } else {
                    ProgressView("Loading Incidents...")
                }
            }
            .navigationTitle("Incidents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingIncident = true
                    } label: {
                        Label("Add Incident", systemImage: "plus")
                    }
                    .disabled(spaceRepo.selectedSpace == nil || incidentStore == nil)
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await incidentStore?.syncPending() }
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(incidentStore?.isSyncing == true || spaceRepo.selectedSpace == nil)
                }
            }
            .sheet(isPresented: $isAddingIncident) {
                if let incidentStore {
                    AddIncidentView(store: incidentStore, userId: authRepo.currentUser?.id)
                        #if os(iOS)
                        .presentationDetents([.medium])
                        #endif
                        #if os(macOS)
                        .frame(minWidth: 520, minHeight: 420)
                        #endif
                }
            }
            .sheet(item: $editingIncident) { incident in
                if let incidentStore {
                    EditIncidentView(store: incidentStore, incident: incident, userId: authRepo.currentUser?.id)
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
                guard let incidentStore else { return }
                incidentStore.setSpace(newValue)
                Task { await incidentStore.refreshRemote() }
            }
        }
    }

    @ViewBuilder
    private func content(store: IncidentStore) -> some View {
        List {
            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ForEach(store.incidents) { incident in
                HStack {
                    if let iconName = incident.iconName, !iconName.isEmpty {
                        Image(systemName: iconName)
                            .foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading) {
                        Text(incident.title)
                            .font(.headline)

                        if let description = incident.incidentDescription, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(incident.occurrenceDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if incident.imageData != nil {
                            Text("Image attached")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Menu {
                        Button {
                            editingIncident = incident
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task {
                                await store.deleteIncident(incident, userId: authRepo.currentUser?.id)
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
        guard incidentStore == nil else { return }

        let repo = IncidentRepository(client: SupabaseConfig.client, context: modelContext)
        let store = IncidentStore(modelContext: modelContext, repository: repo)
        incidentStore = store

        store.setSpace(spaceRepo.selectedSpace?.id)
        if !isPreview {
            await store.refreshRemote()
        }
    }
}

private struct AddIncidentView: View {
    @Environment(\.dismiss) private var dismiss

    let store: IncidentStore
    let userId: UUID?

    @State private var title = ""
    @State private var details = ""
    @State private var date = Date()
    @State private var iconName = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Incident title", text: $title)
                TextField("Description", text: $details)
                TextField("Icon (SF Symbol)", text: $iconName)
                DatePicker("Date", selection: $date)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Select image", systemImage: "photo")
                }
                if imageData != nil {
                    Text("Image selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Save") {
                    Task {
                        await store.addIncident(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: details.isEmpty ? nil : details,
                            occurrenceDate: date,
                            iconName: iconName.isEmpty ? nil : iconName,
                            imageData: imageData,
                            userId: userId
                        )
                        dismiss()
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("New Incident")
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
}

private struct EditIncidentView: View {
    @Environment(\.dismiss) private var dismiss

    let store: IncidentStore
    let incident: Incident
    let userId: UUID?

    @State private var title: String
    @State private var details: String
    @State private var date: Date
    @State private var iconName: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?

    init(store: IncidentStore, incident: Incident, userId: UUID?) {
        self.store = store
        self.incident = incident
        self.userId = userId
        _title = State(initialValue: incident.title)
        _details = State(initialValue: incident.incidentDescription ?? "")
        _date = State(initialValue: incident.occurrenceDate)
        _iconName = State(initialValue: incident.iconName ?? "")
        _imageData = State(initialValue: incident.imageData)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Incident title", text: $title)
                TextField("Description", text: $details)
                TextField("Icon (SF Symbol)", text: $iconName)
                DatePicker("Date", selection: $date)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Select image", systemImage: "photo")
                }
                if imageData != nil {
                    Text("Image selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Save changes") {
                    Task {
                        await store.updateIncident(
                            incident,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: details.isEmpty ? nil : details,
                            occurrenceDate: date,
                            iconName: iconName.isEmpty ? nil : iconName,
                            imageData: imageData,
                            userId: userId
                        )
                        dismiss()
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Edit Incident")
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
}

#Preview("Incidents") {
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
    context.insert(user)

    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))

    context.insert(Incident(spaceId: space.id, title: "Late return", incidentDescription: "School trip", occurrenceDate: .now, createdBy: user.id))
    try? context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return IncidentsListView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
