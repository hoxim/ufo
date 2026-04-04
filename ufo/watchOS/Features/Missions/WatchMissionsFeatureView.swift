#if os(watchOS)
import SwiftUI

struct WatchMissionsFeatureView: View {
    @Environment(WatchAppModel.self) private var model

    @State private var missions: [WatchMissionSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                ProgressView("watch.missions.loading")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if missions.isEmpty {
                Text("watch.missions.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(missions) { mission in
                    NavigationLink {
                        WatchMissionDetailScreen(mission: mission) {
                            await loadMissions()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(mission.title)
                                Spacer(minLength: 8)
                                Image(systemName: mission.isCompleted ? "checkmark.circle.fill" : "clock")
                                    .foregroundStyle(mission.isCompleted ? .green : .orange)
                            }

                            Text(watchLocalizedMissionPriority(mission.priority))
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if let dueDate = mission.dueDate {
                                Text(dueDate, style: .date)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("missions.list.title")
        .task(id: model.selectedSpaceID) {
            await loadMissions()
        }
        .refreshable {
            await loadMissions()
        }
    }

    private func loadMissions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            missions = try await model.fetchMissions()
            errorMessage = nil
        } catch {
            missions = []
            errorMessage = String(localized: "watch.missions.error.load")
        }
    }
}

private struct WatchMissionDetailScreen: View {
    @Environment(WatchAppModel.self) private var model

    let mission: WatchMissionSummary
    let onDidChange: @Sendable () async -> Void

    @State private var detail: WatchMissionDetail?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isSaving = false

    var body: some View {
        List {
            if isLoading {
                ProgressView("watch.missions.loading")
            } else if let detail {
                if !detail.description.isEmpty {
                    Section("watch.common.description") {
                        Text(detail.description)
                    }
                }

                Section("watch.common.details") {
                    LabeledContent("watch.missions.priority") {
                        Text(watchLocalizedMissionPriority(detail.priority))
                    }

                    LabeledContent("missions.editor.field.difficulty") {
                        Text("\(detail.difficulty)/5")
                    }

                    if let dueDate = detail.dueDate {
                        LabeledContent("watch.missions.dueDate") {
                            Text(dueDate, style: .date)
                        }
                    }

                    if let savedPlaceName = detail.savedPlaceName, !savedPlaceName.isEmpty {
                        LabeledContent("watch.missions.place") {
                            Text(savedPlaceName)
                        }
                    }
                }

                Section("watch.common.actions") {
                    Button(detail.isCompleted ? "watch.missions.action.markIncomplete" : "watch.missions.action.markComplete") {
                        Task {
                            await toggleCompleted()
                        }
                    }
                    .disabled(isSaving)
                }

                Section("watch.common.largerScreen") {
                    Text("watch.missions.handoff")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle(mission.title)
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await model.fetchMission(id: mission.id)
            errorMessage = nil
        } catch {
            detail = nil
            errorMessage = String(localized: "watch.missions.error.detail")
        }
    }

    private func toggleCompleted() async {
        guard let detail else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await model.setMissionCompleted(detail, isCompleted: !detail.isCompleted)
            await onDidChange()
            await loadDetail()
        } catch {
            errorMessage = String(localized: "watch.common.error.save")
        }
    }
}

#endif
