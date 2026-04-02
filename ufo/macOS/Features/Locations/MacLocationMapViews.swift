#if os(macOS)

import CoreLocation
import Foundation
import MapKit
import SwiftData
import SwiftUI


struct MacSavedPlacesMapView: View {
    @Environment(\.dismiss) private var dismiss

    let places: [SavedPlace]
    let latestPins: [LocationPing]
    let currentLocation: CLLocation?
    let initialRegion: MKCoordinateRegion

    @State private var region: MKCoordinateRegion
    @State private var position: MapCameraPosition

    init(
        places: [SavedPlace],
        latestPins: [LocationPing],
        currentLocation: CLLocation?,
        initialRegion: MKCoordinateRegion
    ) {
        self.places = places
        self.latestPins = latestPins
        self.currentLocation = currentLocation
        self.initialRegion = initialRegion
        _region = State(initialValue: initialRegion)
        _position = State(initialValue: .region(initialRegion))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $position, interactionModes: .all) {
                    ForEach(annotations) { item in
                        Marker("", coordinate: item.coordinate)
                            .tint(item.tint)
                    }
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    region = context.region
                }
                .ignoresSafeArea(edges: .bottom)

                if !places.isEmpty {
                    List(places) { place in
                        MacSavedPlaceRow(place: place)
                    }
                    .frame(maxHeight: 260)
                }
            }
            .navigationTitle("Places Map")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem { dismiss() }
            }
        }
    }

    private var annotations: [MacLocationAnnotation] {
        var items = places.map {
            MacLocationAnnotation(
                id: $0.id,
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                tint: .teal
            )
        }
        items.append(
            contentsOf: latestPins.map {
                MacLocationAnnotation(
                    id: $0.id,
                    coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                    tint: .red
                )
            }
        )
        if let currentLocation {
            items.append(
                MacLocationAnnotation(
                    id: UUID(),
                    coordinate: currentLocation.coordinate,
                    tint: .blue
                )
            )
        }
        return items
    }
}

struct MacSavedPlaceRow: View {
    let place: SavedPlace

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: place.iconColorHex ?? "#0F766E").opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: place.iconName ?? "mappin.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: place.iconColorHex ?? "#0F766E"))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(place.name)
                        .font(.headline)

                    Text(place.resolvedCategory.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }

                if let description = place.placeDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let address = place.address, !address.isEmpty {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text("\(place.latitude.formatted(.number.precision(.fractionLength(5)))) , \(place.longitude.formatted(.number.precision(.fractionLength(5))))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct MacLocationsMapCard: View {
    @Binding var region: MKCoordinateRegion
    let places: [SavedPlace]
    let latestPins: [LocationPing]
    let currentLocation: CLLocation?
    let height: CGFloat
    @State private var position: MapCameraPosition
    @State private var renderedRegion: MKCoordinateRegion

    init(
        region: Binding<MKCoordinateRegion>,
        places: [SavedPlace],
        latestPins: [LocationPing],
        currentLocation: CLLocation?,
        height: CGFloat = 236
    ) {
        self._region = region
        self.places = places
        self.latestPins = latestPins
        self.currentLocation = currentLocation
        self.height = height
        _position = State(initialValue: .region(region.wrappedValue))
        _renderedRegion = State(initialValue: region.wrappedValue)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $position, interactionModes: .all) {
                ForEach(annotations) { item in
                    Marker("", coordinate: item.coordinate)
                        .tint(item.tint)
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                renderedRegion = context.region
                region = context.region
            }
            .onChange(of: regionSignature) { _, _ in
                syncMapPositionIfNeeded()
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 8) {
                if currentLocation != nil {
                    Label("Current location available", systemImage: "location.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var regionSignature: [Double] {
        [
            region.center.latitude,
            region.center.longitude,
            region.span.latitudeDelta,
            region.span.longitudeDelta
        ]
    }

    private var annotations: [MacLocationAnnotation] {
        var items = places.map {
            MacLocationAnnotation(
                id: $0.id,
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                tint: .teal
            )
        }
        items.append(
            contentsOf: latestPins.map {
                MacLocationAnnotation(
                    id: $0.id,
                    coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                    tint: .red
                )
            }
        )
        if let currentLocation {
            items.append(
                MacLocationAnnotation(
                    id: UUID(),
                    coordinate: currentLocation.coordinate,
                    tint: .blue
                )
            )
        }
        return items
    }

    private func syncMapPositionIfNeeded() {
        guard !Self.regionsMatch(region, renderedRegion) else { return }
        renderedRegion = region
        position = .region(region)
    }

    private static func regionsMatch(_ lhs: MKCoordinateRegion, _ rhs: MKCoordinateRegion) -> Bool {
        abs(lhs.center.latitude - rhs.center.latitude) < 0.000_001 &&
        abs(lhs.center.longitude - rhs.center.longitude) < 0.000_001 &&
        abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) < 0.000_001 &&
        abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) < 0.000_001
    }
}

struct MacLocationPickerMap: View {
    @Binding var region: MKCoordinateRegion
    let places: [SavedPlace]
    let currentLocation: CLLocation?
    @State private var position: MapCameraPosition

    init(
        region: Binding<MKCoordinateRegion>,
        places: [SavedPlace],
        currentLocation: CLLocation?
    ) {
        self._region = region
        self.places = places
        self.currentLocation = currentLocation
        _position = State(initialValue: .region(region.wrappedValue))
    }

    var body: some View {
        ZStack {
            Map(position: $position, interactionModes: .all) {
                ForEach(annotations) { item in
                    Annotation("", coordinate: item.coordinate) {
                        Circle()
                            .fill(item.tint)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.95), lineWidth: 3)
                            }
                            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                region = context.region
            }

            VStack {
                Text("Środek mapy")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 12)

                Spacer()
            }

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 34, height: 34)

                Circle()
                    .strokeBorder(Color.white.opacity(0.95), lineWidth: 2)
                    .frame(width: 28, height: 28)

                Rectangle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 2, height: 22)

                Rectangle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 22, height: 2)
            }
            .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var annotations: [MacLocationAnnotation] {
        var items = places.map {
            MacLocationAnnotation(
                id: $0.id,
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                tint: .teal
            )
        }

        if let currentLocation {
            items.append(
                MacLocationAnnotation(
                    id: UUID(),
                    coordinate: currentLocation.coordinate,
                    tint: .blue
                )
            )
        }

        return items
    }
}


private struct MacLocationAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let tint: Color
}

#endif
