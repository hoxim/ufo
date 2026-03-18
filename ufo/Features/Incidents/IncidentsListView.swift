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
    @State private var viewingIncident: Incident?
    @State private var didAutoPresentAdd = false
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    let autoPresentAdd: Bool

    init(autoPresentAdd: Bool = false) {
        self.autoPresentAdd = autoPresentAdd
    }

    var body: some View {
        NavigationStack {
            Group {
                if let incidentStore {
                    content(store: incidentStore)
                } else {
                    ProgressView("incidents.list.loading")
                }
            }
            .navigationTitle("incidents.list.title")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingIncident = true
                    } label: {
                        Label("incidents.list.action.add", systemImage: "plus")
                    }
                    .disabled(spaceRepo.selectedSpace == nil || incidentStore == nil)
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await incidentStore?.syncPending() }
                    } label: {
                        Label("common.sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(incidentStore?.isSyncing == true || spaceRepo.selectedSpace == nil)
                }
            }
            .sheet(isPresented: $isAddingIncident) {
                if let incidentStore {
                    AddIncidentView(store: incidentStore, userId: authRepo.currentUser?.id)
                        #if os(iOS)
                        .presentationDetents([.medium, .large])
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
                        .presentationDetents([.medium, .large])
                        #endif
                        #if os(macOS)
                        .frame(minWidth: 520, minHeight: 420)
                        #endif
                }
            }
            .sheet(item: $viewingIncident) { incident in
                IncidentDetailView(
                    incident: incident,
                    onEdit: {
                        viewingIncident = nil
                        DispatchQueue.main.async {
                            editingIncident = incident
                        }
                    }
                )
            }
            .task {
                await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
                if autoPresentAdd && !didAutoPresentAdd && incidentStore != nil {
                    didAutoPresentAdd = true
                    try? await Task.sleep(for: .milliseconds(300))
                    isAddingIncident = true
                }
            }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                guard let incidentStore else { return }
                incidentStore.setSpace(newValue)
                Task { await incidentStore.refreshRemote() }
            }
        }
    }

    @ViewBuilder
    /// Handles content.
    private func content(store: IncidentStore) -> some View {
        List {
            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ForEach(store.incidents) { incident in
                HStack {
                    Button {
                        viewingIncident = incident
                    } label: {
                        HStack {
                            if let iconName = incident.iconName, !iconName.isEmpty {
                                Image(systemName: iconName)
                                    .foregroundStyle(Color(hex: incident.iconColorHex ?? "#F59E0B"))
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
                                Text("\(IncidentSeverity(rawValue: incident.resolvedSeverity)?.localizedLabel ?? incident.resolvedSeverity.capitalized) · \(IncidentStatus(rawValue: incident.resolvedStatus)?.localizedLabel ?? incident.resolvedStatus.capitalized)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let cost = incident.cost {
                                    Text(cost.formatted(.currency(code: "PLN")))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if incident.imageData != nil {
                                    Text("common.imageAttached")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Menu {
                        Button {
                            editingIncident = incident
                        } label: {
                            Label("common.edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task {
                                await store.deleteIncident(incident, userId: authRepo.currentUser?.id)
                            }
                        } label: {
                            Label("common.delete", systemImage: "trash")
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
                ProgressView("common.synchronizing")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @MainActor
    /// Sets up store if needed.
    private func setupStoreIfNeeded(performRemoteRefresh: Bool = true) async {
        guard incidentStore == nil else { return }

        let repo = IncidentRepository(client: SupabaseConfig.client, context: modelContext)
        let store = IncidentStore(modelContext: modelContext, repository: repo)
        incidentStore = store

        store.setSpace(spaceRepo.selectedSpace?.id)
        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
        }
    }
}

private struct IncidentDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let incident: Incident
    let onEdit: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if let iconName = incident.iconName, !iconName.isEmpty {
                            Image(systemName: iconName)
                                .foregroundStyle(Color(hex: incident.iconColorHex ?? "#F59E0B"))
                        }
                        Text(incident.title)
                            .font(.title2.bold())
                    }

                    if let description = incident.incidentDescription, !description.isEmpty {
                        Text(description)
                            .font(.body)
                    }

                    HStack(spacing: 10) {
                        Label(IncidentSeverity(rawValue: incident.resolvedSeverity)?.localizedLabel ?? incident.resolvedSeverity.capitalized, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                        Label(IncidentStatus(rawValue: incident.resolvedStatus)?.localizedLabel ?? incident.resolvedStatus.capitalized, systemImage: "clock")
                            .font(.caption)
                        if let cost = incident.cost {
                            Label(cost.formatted(.currency(code: "PLN")), systemImage: "dollarsign.circle")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)

                    Text(incident.occurrenceDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("incidents.list.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onEdit()
                    } label: {
                        Label("common.edit", systemImage: "pencil")
                    }
                }
            }
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
    @State private var severity: IncidentSeverity = .medium
    @State private var status: IncidentStatus = .open
    @State private var assigneeId: UUID?
    @State private var costText = ""
    @State private var iconName = "bolt.horizontal"
    @State private var iconColorHex = "#F59E0B"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false
    @State private var showStylePicker = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("incidents.editor.field.title", text: $title)
                TextField("incidents.editor.field.description", text: $details)
                DatePicker("incidents.editor.field.date", selection: $date)
                Picker("Severity", selection: $severity) {
                    ForEach(IncidentSeverity.allCases) { value in
                        Text(value.localizedLabel).tag(value)
                    }
                }
                Picker("Status", selection: $status) {
                    ForEach(IncidentStatus.allCases) { value in
                        Text(value.localizedLabel).tag(value)
                    }
                }
                Picker("Assignee", selection: $assigneeId) {
                    Text("Unassigned").tag(UUID?.none)
                    if let currentUser = userId {
                        Text(currentUser.uuidString.prefix(8)).tag(UUID?.some(currentUser))
                    }
                }
                TextField("Cost", text: $costText)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                DisclosureGroup("Style", isExpanded: $showStylePicker) {
                    OperationStylePicker(iconName: $iconName, colorHex: $iconColorHex)
                }
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("common.selectImage", systemImage: "photo")
                }
                if imageData != nil {
                    Text("common.imageSelected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            }
            .navigationTitle("incidents.editor.title.new")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
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

        await store.addIncident(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: details.isEmpty ? nil : details,
            severity: severity.rawValue,
            status: status.rawValue,
            assigneeId: assigneeId,
            cost: Double(costText.replacingOccurrences(of: ",", with: ".")),
            occurrenceDate: date,
            iconName: iconName.isEmpty ? nil : iconName,
            iconColorHex: iconColorHex,
            imageData: imageData,
            userId: userId
        )
        dismiss()
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
    @State private var severity: IncidentSeverity
    @State private var status: IncidentStatus
    @State private var assigneeId: UUID?
    @State private var costText: String
    @State private var iconName: String
    @State private var iconColorHex: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false
    @State private var showStylePicker = false

    init(store: IncidentStore, incident: Incident, userId: UUID?) {
        self.store = store
        self.incident = incident
        self.userId = userId
        _title = State(initialValue: incident.title)
        _details = State(initialValue: incident.incidentDescription ?? "")
        _date = State(initialValue: incident.occurrenceDate)
        _severity = State(initialValue: IncidentSeverity(rawValue: incident.resolvedSeverity) ?? .medium)
        _status = State(initialValue: IncidentStatus(rawValue: incident.resolvedStatus) ?? .open)
        _assigneeId = State(initialValue: incident.assigneeId)
        _costText = State(initialValue: incident.cost.map { String($0) } ?? "")
        _iconName = State(initialValue: incident.iconName ?? "bolt.horizontal")
        _iconColorHex = State(initialValue: incident.iconColorHex ?? "#F59E0B")
        _imageData = State(initialValue: incident.imageData)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("incidents.editor.field.title", text: $title)
                TextField("incidents.editor.field.description", text: $details)
                DatePicker("incidents.editor.field.date", selection: $date)
                Picker("Severity", selection: $severity) {
                    ForEach(IncidentSeverity.allCases) { value in
                        Text(value.localizedLabel).tag(value)
                    }
                }
                Picker("Status", selection: $status) {
                    ForEach(IncidentStatus.allCases) { value in
                        Text(value.localizedLabel).tag(value)
                    }
                }
                Picker("Assignee", selection: $assigneeId) {
                    Text("Unassigned").tag(UUID?.none)
                    if let currentUser = userId {
                        Text(currentUser.uuidString.prefix(8)).tag(UUID?.some(currentUser))
                    }
                }
                TextField("Cost", text: $costText)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                DisclosureGroup("Style", isExpanded: $showStylePicker) {
                    OperationStylePicker(iconName: $iconName, colorHex: $iconColorHex)
                }
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("common.selectImage", systemImage: "photo")
                }
                if imageData != nil {
                    Text("common.imageSelected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            }
            .navigationTitle("incidents.editor.title.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
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

        await store.updateIncident(
            incident,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: details.isEmpty ? nil : details,
            severity: severity.rawValue,
            status: status.rawValue,
            assigneeId: assigneeId,
            cost: Double(costText.replacingOccurrences(of: ",", with: ".")),
            occurrenceDate: date,
            iconName: iconName.isEmpty ? nil : iconName,
            iconColorHex: iconColorHex,
            imageData: imageData,
            userId: userId
        )
        dismiss()
    }
}

#Preview("incidents.list.title") {
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
    do {
        try context.save()
    } catch {
        Log.dbError("Incidents preview context.save", error)
    }

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return IncidentsListView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
