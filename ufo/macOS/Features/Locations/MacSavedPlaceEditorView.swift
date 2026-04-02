#if os(macOS)

import CoreLocation
import Foundation
import MapKit
import SwiftData
import SwiftUI


enum MacSavedPlaceInputMethod: String, CaseIterable, Identifiable {
    case address
    case currentLocation
    case coordinates
    case mapCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .address: return "Address"
        case .currentLocation: return "Current"
        case .coordinates: return "Coords"
        case .mapCenter: return "Map"
        }
    }

    var symbolName: String {
        switch self {
        case .address: return "magnifyingglass"
        case .currentLocation: return "location.fill"
        case .coordinates: return "number"
        case .mapCenter: return "scope"
        }
    }

    var helperText: String {
        switch self {
        case .address:
            return "Wpisz adres albo nazwę miejsca i potwierdź pierwszy znaleziony punkt."
        case .currentLocation:
            return "Pobierz bieżącą lokalizację telefonu i użyj jej jako miejsca."
        case .coordinates:
            return "Wpisz ręcznie szerokość i długość geograficzną, a potem zatwierdź punkt."
        case .mapCenter:
            return "Przesuń mapę tak, żeby znacznik na środku wskazywał dokładne miejsce."
        }
    }

    var selectionTitle: String {
        switch self {
        case .address: return "Wybrano z adresu"
        case .currentLocation: return "Wybrano z bieżącej lokalizacji"
        case .coordinates: return "Wybrano z koordynatów"
        case .mapCenter: return "Wybrano z mapy"
        }
    }
}

struct MacAddSavedPlaceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: MacLocationViewModel
    let actorId: UUID?
    let placeToEdit: SavedPlace?
    var originLabel: String? = nil
    var onCreated: ((SavedPlace) -> Void)? = nil

    @State private var title = ""
    @State private var description = ""
    @State private var address = ""
    @State private var iconName = "mappin.circle.fill"
    @State private var iconColorHex = "#0F766E"
    @State private var category: SavedPlaceCategory = .other
    @State private var method: MacSavedPlaceInputMethod = .address
    @State private var addressQuery = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedSource: MacSavedPlaceInputMethod?
    @State private var pickerRegion: MKCoordinateRegion
    @State private var isSaving = false
    @State private var activeSourceAction: MacSavedPlaceInputMethod?
    @State private var isWaitingForCurrentLocation = false
    @State private var showStylePicker = false

    init(
        viewModel: MacLocationViewModel,
        actorId: UUID?,
        placeToEdit: SavedPlace? = nil,
        originLabel: String? = nil,
        onCreated: ((SavedPlace) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.actorId = actorId
        self.placeToEdit = placeToEdit
        self.originLabel = originLabel
        self.onCreated = onCreated

        let existingAddress = placeToEdit?.address ?? ""
        let existingCoordinate = placeToEdit.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        _title = State(initialValue: placeToEdit?.name ?? "")
        _description = State(initialValue: placeToEdit?.placeDescription ?? "")
        _address = State(initialValue: existingAddress)
        _iconName = State(initialValue: placeToEdit?.iconName ?? "mappin.circle.fill")
        _iconColorHex = State(initialValue: placeToEdit?.iconColorHex ?? "#0F766E")
        _category = State(initialValue: placeToEdit?.resolvedCategory ?? .other)
        _method = State(initialValue: existingAddress.isEmpty ? .coordinates : .address)
        _addressQuery = State(initialValue: existingAddress)
        _latitudeText = State(initialValue: existingCoordinate.map { Self.formattedCoordinate($0.latitude) } ?? "")
        _longitudeText = State(initialValue: existingCoordinate.map { Self.formattedCoordinate($0.longitude) } ?? "")
        _selectedCoordinate = State(initialValue: existingCoordinate)
        _selectedSource = State(initialValue: placeToEdit == nil ? nil : (existingAddress.isEmpty ? .coordinates : .address))
        _pickerRegion = State(
            initialValue: existingCoordinate.map(Self.region(centeredAt:)) ?? viewModel.region
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let originLabel {
                    Section {
                        OpenedFromBadge(title: originLabel)
                    }
                }
                Section("Place") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Category", selection: $category) {
                        ForEach(SavedPlaceCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                }

                Section("Location") {
                    Picker("Input method", selection: $method) {
                        ForEach(MacSavedPlaceInputMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(method.helperText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let locationError = viewModel.locationErrorMessage, !locationError.isEmpty {
                        Text(locationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if method == .address {
                        TextField("Search address or place", text: $addressQuery, axis: .vertical)
                            .lineLimit(1...3)
                            .searchSubmitLabelIfSupported()
                            .onSubmit {
                                Task { await resolveAddressSelection() }
                            }

                        Button {
                            Task { await resolveAddressSelection() }
                        } label: {
                            if activeSourceAction == .address {
                                ProgressView()
                            } else {
                                Label("Use found address", systemImage: "magnifyingglass")
                            }
                        }
                        .disabled(addressQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || activeSourceAction != nil)
                    }

                    if method == .currentLocation {
                        Button {
                            Task { await useCurrentLocationSelection() }
                        } label: {
                            if activeSourceAction == .currentLocation {
                                ProgressView()
                            } else {
                                Label("Use current location", systemImage: "location.fill")
                            }
                        }
                        .disabled(activeSourceAction != nil)

                        if isWaitingForCurrentLocation {
                            Text("Waiting for a fresh GPS location...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if method == .coordinates {
                        TextField("Latitude", text: $latitudeText)
                            .decimalPadKeyboardIfSupported()

                        TextField("Longitude", text: $longitudeText)
                            .decimalPadKeyboardIfSupported()

                        Button {
                            Task { await useTypedCoordinatesSelection() }
                        } label: {
                            if activeSourceAction == .coordinates {
                                ProgressView()
                            } else {
                                Label("Use coordinates", systemImage: "number")
                            }
                        }
                        .disabled(activeSourceAction != nil)
                    }

                    if method == .mapCenter {
                        MacLocationPickerMap(
                            region: $pickerRegion,
                            places: viewModel.locationStore?.savedPlaces ?? [],
                            currentLocation: viewModel.currentLocation
                        )
                        .listRowInsets(EdgeInsets())

                        Button {
                            Task { await useMapCenterSelection() }
                        } label: {
                            if activeSourceAction == .mapCenter {
                                ProgressView()
                            } else {
                                Label("Use visible map center", systemImage: "scope")
                            }
                        }
                        .disabled(activeSourceAction != nil)
                    }
                }

                if let selectedCoordinate, let selectedSource {
                    Section("Selected location") {
                        MacLocationSelectionSummary(
                            method: selectedSource,
                            address: address,
                            coordinate: selectedCoordinate
                        )
                    }
                }

                Section("Style") {
                    DisclosureGroup("Customize icon", isExpanded: $showStylePicker) {
                        OperationStylePicker(iconName: $iconName, colorHex: $iconColorHex)
                    }
                }
            }
            .navigationTitle(placeToEdit == nil ? "Add Place" : "Edit Place")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCoordinate == nil || isSaving,
                    isProcessing: isSaving,
                    action: {
                        Task { await save() }
                    }
                )
            }
            .task {
                syncCoordinatesFromViewModel()
            }
            .onChange(of: method) { _, _ in
                isWaitingForCurrentLocation = false
                viewModel.locationErrorMessage = nil
            }
            .onChange(of: viewModel.currentLocation?.coordinate.latitude) { _, _ in
                Task { await handlePendingCurrentLocationSelection() }
            }
            .onChange(of: viewModel.currentLocation?.coordinate.longitude) { _, _ in
                Task { await handlePendingCurrentLocationSelection() }
            }
        }
    }

    private func syncCoordinatesFromViewModel() {
        latitudeText = viewModel.latitudeText
        longitudeText = viewModel.longitudeText
    }

    private nonisolated static func region(centeredAt coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }

    private func resolveAddressSelection() async {
        let trimmed = addressQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        activeSourceAction = .address
        defer { activeSourceAction = nil }

        guard let coordinate = await viewModel.resolveAddress(trimmed) else { return }
        latitudeText = formatCoordinate(coordinate.latitude)
        longitudeText = formatCoordinate(coordinate.longitude)
        pickerRegion = Self.region(centeredAt: coordinate)
        await finalizeSelection(
            coordinate: coordinate,
            fallbackAddress: trimmed,
            source: .address
        )
    }

    private func useCurrentLocationSelection() async {
        activeSourceAction = .currentLocation
        viewModel.useCurrentLocationForInput()
        syncCoordinatesFromViewModel()

        guard let coordinate = viewModel.currentCoordinate() else {
            isWaitingForCurrentLocation = true
            activeSourceAction = nil
            return
        }

        isWaitingForCurrentLocation = false
        defer { activeSourceAction = nil }
        pickerRegion = Self.region(centeredAt: coordinate)

        await finalizeSelection(
            coordinate: coordinate,
            fallbackAddress: nil,
            source: .currentLocation
        )
    }

    private func handlePendingCurrentLocationSelection() async {
        guard method == .currentLocation, isWaitingForCurrentLocation, let coordinate = viewModel.currentCoordinate() else {
            return
        }

        activeSourceAction = .currentLocation
        isWaitingForCurrentLocation = false
        syncCoordinatesFromViewModel()
        pickerRegion = Self.region(centeredAt: coordinate)
        await finalizeSelection(
            coordinate: coordinate,
            fallbackAddress: nil,
            source: .currentLocation
        )
        activeSourceAction = nil
    }

    private func useTypedCoordinatesSelection() async {
        guard
            let latitude = Double(latitudeText.replacingOccurrences(of: ",", with: ".")),
            let longitude = Double(longitudeText.replacingOccurrences(of: ",", with: "."))
        else {
            viewModel.locationErrorMessage = "Enter valid latitude and longitude."
            return
        }

        activeSourceAction = .coordinates
        defer { activeSourceAction = nil }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        pickerRegion = Self.region(centeredAt: coordinate)
        await finalizeSelection(
            coordinate: coordinate,
            fallbackAddress: nil,
            source: .coordinates
        )
    }

    private func useMapCenterSelection() async {
        activeSourceAction = .mapCenter
        defer { activeSourceAction = nil }

        let coordinate = pickerRegion.center
        latitudeText = formatCoordinate(coordinate.latitude)
        longitudeText = formatCoordinate(coordinate.longitude)
        await finalizeSelection(
            coordinate: coordinate,
            fallbackAddress: nil,
            source: .mapCenter
        )
    }

    private func finalizeSelection(
        coordinate: CLLocationCoordinate2D,
        fallbackAddress: String?,
        source: MacSavedPlaceInputMethod
    ) async {
        selectedCoordinate = coordinate
        selectedSource = source

        if let resolved = await viewModel.reverseGeocode(coordinate: coordinate), !resolved.isEmpty {
            address = resolved
        } else {
            address = fallbackAddress ?? ""
        }

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let suggestedTitle = suggestedTitle(from: address) {
            title = suggestedTitle
        }

        viewModel.locationErrorMessage = nil
    }

    private func suggestedTitle(from address: String) -> String? {
        let firstPart = address
            .split(separator: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstPart, !firstPart.isEmpty else { return nil }
        return firstPart
    }

    private func formatCoordinate(_ value: Double) -> String {
        Self.formattedCoordinate(value)
    }

    private static func formattedCoordinate(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(6)))
    }

    private func save() async {
        guard let selectedCoordinate else {
            viewModel.locationStore?.lastErrorMessage = "Invalid location input."
            Log.error("MacAddSavedPlaceSheet.save invalid coordinate. method=\(method.rawValue) title=\(title)")
            return
        }

        isSaving = true
        defer { isSaving = false }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPlace: SavedPlace?

        if let placeToEdit {
            Log.msg("MacAddSavedPlaceSheet.save updating placeId=\(placeToEdit.id.uuidString) title=\(cleanTitle)")
            savedPlace = await viewModel.locationStore?.updateSavedPlace(
                placeToEdit,
                name: cleanTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                category: category.rawValue,
                iconName: iconName.isEmpty ? nil : iconName,
                iconColorHex: iconColorHex,
                address: trimmedAddress.isEmpty ? nil : trimmedAddress,
                latitude: selectedCoordinate.latitude,
                longitude: selectedCoordinate.longitude,
                radiusMeters: placeToEdit.radiusMeters,
                actor: actorId
            )
        } else {
            Log.msg("MacAddSavedPlaceSheet.save creating title=\(cleanTitle) method=\(method.rawValue) lat=\(selectedCoordinate.latitude) lon=\(selectedCoordinate.longitude) selectedSpace=\(viewModel.locationStore?.currentSpaceId?.uuidString ?? "nil")")
            savedPlace = await viewModel.locationStore?.addSavedPlace(
                name: cleanTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                category: category.rawValue,
                iconName: iconName.isEmpty ? nil : iconName,
                iconColorHex: iconColorHex,
                address: trimmedAddress.isEmpty ? nil : trimmedAddress,
                latitude: selectedCoordinate.latitude,
                longitude: selectedCoordinate.longitude,
                radiusMeters: 100,
                actor: actorId
            )
        }

        Log.msg("MacAddSavedPlaceSheet.save finished title=\(cleanTitle) savedPlace=\(savedPlace?.id.uuidString ?? "nil") lastError=\(viewModel.locationStore?.lastErrorMessage ?? "nil")")
        if let savedPlace {
            onCreated?(savedPlace)
            dismiss()
        }
    }
}


private struct MacLocationSelectionSummary: View {
    let method: MacSavedPlaceInputMethod
    let address: String
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: method.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accent)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(method.selectionTitle)
                        .font(.subheadline.weight(.semibold))

                    if !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text("\(coordinate.latitude.formatted(.number.precision(.fractionLength(6)))) , \(coordinate.longitude.formatted(.number.precision(.fractionLength(6))))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}



#endif
