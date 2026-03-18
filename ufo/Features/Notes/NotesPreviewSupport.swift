import Foundation
import SwiftData

@MainActor
struct NotesPreviewData {
    let container: ModelContainer
    let user: UserProfile
    let space: Space
    let store: NoteStore
    let note: Note
    let folders: [NoteFolder]
    let incidents: [Incident]
    let locations: [LocationPing]
    let savedPlaces: [SavedPlace]
}

@MainActor
enum NotesPreviewFactory {
    static func make() -> NotesPreviewData {
        let schema = Schema([
            UserProfile.self,
            Space.self,
            SpaceMembership.self,
            Note.self,
            NoteFolder.self,
            Incident.self,
            LocationPing.self,
            SavedPlace.self
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
        let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
        let folder = NoteFolder(spaceId: space.id, name: "Work", createdBy: user.id)
        let incident = Incident(
            spaceId: space.id,
            title: "Storm",
            incidentDescription: "Strong wind",
            occurrenceDate: .now,
            createdBy: user.id
        )
        let location = LocationPing(
            spaceId: space.id,
            userId: user.id,
            userDisplayName: "Preview User",
            latitude: 52.22,
            longitude: 21.01
        )
        let savedPlace = SavedPlace(
            spaceId: space.id,
            name: "Home",
            placeDescription: "Family base",
            iconName: "house.fill",
            iconColorHex: "#0F766E",
            address: "Marszalkowska 1, Warszawa",
            latitude: 52.2297,
            longitude: 21.0122,
            createdBy: user.id
        )
        let note = Note(
            spaceId: space.id,
            title: "Trip note",
            content: "Remember passports and chargers before leaving.",
            folderId: folder.id,
            attachedLinkURL: "https://example.com",
            savedPlaceId: savedPlace.id,
            savedPlaceName: savedPlace.name,
            relatedIncidentId: incident.id,
            relatedLocationLatitude: location.latitude,
            relatedLocationLongitude: location.longitude,
            relatedLocationLabel: location.userDisplayName,
            createdBy: user.id
        )

        context.insert(user)
        context.insert(space)
        context.insert(SpaceMembership(user: user, space: space, role: "admin"))
        context.insert(folder)
        context.insert(incident)
        context.insert(location)
        context.insert(savedPlace)
        context.insert(note)

        try? context.save()

        let repository = NoteRepository(client: SupabaseConfig.client, context: context)
        let store = NoteStore(modelContext: context, repository: repository)
        store.setSpace(space.id)

        return NotesPreviewData(
            container: container,
            user: user,
            space: space,
            store: store,
            note: note,
            folders: [folder],
            incidents: [incident],
            locations: [location],
            savedPlaces: [savedPlace]
        )
    }
}
