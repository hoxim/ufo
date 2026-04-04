#if os(watchOS)
import SwiftUI

struct WatchLocationsFeatureView: View {
    @Environment(WatchAppModel.self) private var model

    @State private var places: [WatchSavedPlaceSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                ProgressView("watch.locations.loading")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if places.isEmpty {
                Text("watch.locations.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(places) { place in
                    NavigationLink {
                        WatchLocationDetailScreen(place: place)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name)
                            if let address = place.address, !address.isEmpty {
                                Text(address)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            } else if let category = place.category, !category.isEmpty {
                                Text(watchLocalizedPlaceCategory(category))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("watch.locations.title")
        .task(id: model.selectedSpaceID) {
            await loadPlaces()
        }
        .refreshable {
            await loadPlaces()
        }
    }

    private func loadPlaces() async {
        isLoading = true
        defer { isLoading = false }

        do {
            places = try await model.fetchSavedPlaces()
            errorMessage = nil
        } catch {
            places = []
            errorMessage = String(localized: "watch.locations.error.load")
        }
    }
}

private struct WatchLocationDetailScreen: View {
    @Environment(\.openURL) private var openURL

    let place: WatchSavedPlaceSummary

    var body: some View {
        List {
            if let description = place.description, !description.isEmpty {
                Section("watch.common.description") {
                    Text(description)
                }
            }

            Section("watch.common.details") {
                if let category = place.category, !category.isEmpty {
                    LabeledContent("watch.locations.category") {
                        Text(watchLocalizedPlaceCategory(category))
                    }
                }

                if let address = place.address, !address.isEmpty {
                    LabeledContent("watch.locations.address") {
                        Text(address)
                    }
                }

                LabeledContent("watch.locations.radius") {
                    Text(String(format: String(localized: "watch.locations.radiusValue"), Int(place.radiusMeters)))
                }
            }

            Section("watch.locations.map") {
                Button("watch.locations.openInMaps") {
                    if let url = mapsURL(for: place) {
                        openURL(url)
                    }
                }
            }

            Section("watch.common.largerScreen") {
                Text("watch.locations.handoff")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(place.name)
    }

    private func mapsURL(for place: WatchSavedPlaceSummary) -> URL? {
        let encodedName = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.name
        return URL(string: "http://maps.apple.com/?ll=\(place.latitude),\(place.longitude)&q=\(encodedName)")
    }
}

#endif
