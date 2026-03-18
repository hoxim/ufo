import SwiftUI
import SwiftData

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNotificationStore.self) private var notificationStore

    @State private var filter: NotificationReadFilter = .all
    @State private var selectedCategory: AppNotificationCategory?

    var body: some View {
        NavigationStack {
            List {
                filterSection

                if let error = notificationStore.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if filteredNotifications.isEmpty {
                    Section {
                        ContentUnavailableView(
                            emptyStateTitle,
                            systemImage: "bell.slash",
                            description: Text(emptyStateDescription)
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(filteredNotifications) { notification in
                        Button {
                            notificationStore.markAsRead(notification)
                        } label: {
                            NotificationRowView(notification: notification)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                notificationStore.delete(notification)
                            } label: {
                                Label("Usuń", systemImage: "trash")
                            }

                            if !notification.isRead {
                                Button {
                                    notificationStore.markAsRead(notification)
                                } label: {
                                    Label("Przeczytane", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Powiadomienia")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    if filter == .unread && !filteredNotifications.isEmpty {
                        Button("Oznacz wszystkie") {
                            notificationStore.markAllAsRead()
                        }
                    }

                    if notificationStore.pushAuthorizationStatus != .authorized {
                        Button {
                            Task { await notificationStore.requestPushAuthorization() }
                        } label: {
                            Label("Włącz push", systemImage: "bell.badge")
                        }
                    }
                }
            }
            .task {
                await notificationStore.refreshPushAuthorizationStatus()
            }
        }
    }

    private var filterSection: some View {
        Section {
            Picker("Filtr", selection: $filter) {
                ForEach(NotificationReadFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "Wszystkie", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(AppNotificationCategory.allCases) { category in
                        filterChip(title: category.title, isSelected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.1), in: Capsule())
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private var filteredNotifications: [AppNotification] {
        notificationStore.notifications.filter { notification in
            let matchesReadState = switch filter {
            case .all:
                true
            case .unread:
                !notification.isRead
            case .read:
                notification.isRead
            }

            let matchesCategory = selectedCategory == nil || notification.category == selectedCategory
            return matchesReadState && matchesCategory
        }
    }

    private var emptyStateTitle: String {
        switch filter {
        case .all:
            return "Brak powiadomień"
        case .unread:
            return "Brak nieprzeczytanych"
        case .read:
            return "Brak przeczytanych"
        }
    }

    private var emptyStateDescription: String {
        switch filter {
        case .all:
            return "Gdy coś wydarzy się w aplikacji albo ustawisz przypomnienie, pojawi się tutaj."
        case .unread:
            return "Wszystkie powiadomienia zostały już przeczytane."
        case .read:
            return "Nie masz jeszcze przeczytanych powiadomień w tym widoku."
        }
    }
}

private enum NotificationReadFilter: String, CaseIterable, Identifiable {
    case all
    case unread
    case read

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Wszystkie"
        case .unread:
            return "Nieprzeczytane"
        case .read:
            return "Przeczytane"
        }
    }
}

private struct NotificationRowView: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconTint.opacity(0.14))
                    .frame(width: 36, height: 36)

                Image(systemName: notification.category.symbolName)
                    .foregroundStyle(iconTint)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(notification.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if !notification.isRead {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                    }

                    Spacer(minLength: 0)
                }

                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(notification.category.title)
                    Text(notification.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let scheduledAt = notification.scheduledAt {
                        Text("Zaplanowano: \(scheduledAt.formatted(date: .omitted, time: .shortened))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconTint: Color {
        switch notification.priority {
        case .passive:
            return .secondary
        case .normal:
            return .blue
        case .important:
            return .orange
        case .critical:
            return .red
        }
    }
}

#Preview("Notification Center") {
    NotificationCenterPreview()
}

private struct NotificationCenterPreview: View {
    private let container: ModelContainer
    private let store: AppNotificationStore

    init() {
        let schema = Schema([AppNotification.self])
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = AppNotificationStore(modelContext: container.mainContext)

        store.addNotification(
            title: "Mission dodana",
            body: "Twoja mission została zapisana poprawnie.",
            category: .info,
            priority: .normal
        )
        store.addNotification(
            title: "Przypomnienie o wizycie",
            body: "Za godzinę masz zaplanowaną wizytę u lekarza.",
            category: .alert,
            priority: .important,
            scheduledAt: .now.addingTimeInterval(3600)
        )

        self.container = container
        self.store = store
    }

    var body: some View {
        NotificationCenterView()
            .environment(store)
            .modelContainer(container)
    }
}
