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
                ProgressView("watch.incidents.loading")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if incidents.isEmpty {
                Text("watch.incidents.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(incidents) { incident in
                    NavigationLink {
                        WatchIncidentDetailScreen(incident: incident) {
                            await loadIncidents()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(incident.title)

                            HStack(spacing: 6) {
                                Text(watchLocalizedIncidentSeverity(incident.severity))
                                Text("·")
                                Text(watchLocalizedIncidentStatus(incident.status))
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("incidents.list.title")
        .task(id: model.selectedSpaceID) {
            await loadIncidents()
        }
        .refreshable {
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
            errorMessage = String(localized: "watch.incidents.error.load")
        }
    }
}

private struct WatchIncidentDetailScreen: View {
    @Environment(WatchAppModel.self) private var model

    let incident: WatchIncidentSummary
    let onDidChange: @Sendable () async -> Void

    @State private var detail: WatchIncidentDetail?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isSaving = false

    var body: some View {
        List {
            if isLoading {
                ProgressView("watch.incidents.loading")
            } else if let detail {
                if let description = detail.description, !description.isEmpty {
                    Section("watch.common.description") {
                        Text(description)
                    }
                }

                Section("watch.common.details") {
                    LabeledContent("watch.incidents.severity") {
                        Text(watchLocalizedIncidentSeverity(detail.severity))
                    }

                    LabeledContent("common.status") {
                        Text(watchLocalizedIncidentStatus(detail.status))
                    }

                    LabeledContent("watch.incidents.date") {
                        Text(detail.occurrenceDate, style: .date)
                    }
                }

                Section("watch.incidents.statusSection") {
                    ForEach(["open", "in_progress", "resolved"], id: \.self) { status in
                        Button(watchLocalizedIncidentStatus(status)) {
                            Task {
                                await updateStatus(status)
                            }
                        }
                        .disabled(isSaving || detail.status == status)
                    }
                }

                Section("watch.common.largerScreen") {
                    Text("watch.incidents.handoff")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle(incident.title)
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await model.fetchIncident(id: incident.id)
            errorMessage = nil
        } catch {
            detail = nil
            errorMessage = String(localized: "watch.incidents.error.detail")
        }
    }

    private func updateStatus(_ status: String) async {
        guard let detail else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await model.updateIncidentStatus(detail, status: status)
            await onDidChange()
            await loadDetail()
        } catch {
            errorMessage = String(localized: "watch.incidents.error.updateStatus")
        }
    }
}

#endif
