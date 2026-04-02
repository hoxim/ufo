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
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if missions.isEmpty {
                Text("Brak missions.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(missions) { mission in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(mission.title)
                            Spacer(minLength: 8)
                            Image(systemName: mission.isCompleted ? "checkmark.circle.fill" : "clock")
                                .foregroundStyle(mission.isCompleted ? .green : .orange)
                        }

                        Text(mission.priority.capitalized)
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
        .navigationTitle("Missions")
        .task(id: model.selectedSpaceID) {
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
            errorMessage = "Nie udało się wczytać missions."
        }
    }
}

#endif
