#if os(watchOS)
import SwiftUI

struct WatchIncidentsFeatureView: View {
    @Environment(WatchAppModel.self) private var model

    @State private var incidents: [WatchIncidentSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if incidents.isEmpty {
                Text("Brak incidents.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(incidents) { incident in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(incident.title)

                        HStack(spacing: 6) {
                            Text(incident.severity.capitalized)
                            Text("·")
                            Text(incident.status.capitalized)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Incidents")
        .task(id: model.selectedSpaceID) {
            await loadIncidents()
        }
    }

    private func loadIncidents() async {
        isLoading = true
        defer { isLoading = false }

        do {
            incidents = try await model.fetchIncidents()
            errorMessage = nil
        } catch {
            incidents = []
            errorMessage = "Nie udało się wczytać incidents."
        }
    }
}

#endif
