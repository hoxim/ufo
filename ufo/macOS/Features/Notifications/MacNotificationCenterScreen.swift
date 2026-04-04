#if os(macOS)

import SwiftUI
import SwiftData
import UserNotifications

struct MacNotificationCenterScreen: View {
    @Environment(AppNotificationStore.self) private var notificationStore

    @State private var filter: NotificationReadFilter = .all
    @State private var selectedCategory: AppNotificationCategory?

    var body: some View {
        List {
            headerSection
            filterSection

            if let error = notificationStore.lastErrorMessage {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if filteredNotifications.isEmpty {
                Section {
                    ContentUnavailableView(
                        emptyStateTitle,
                        systemImage: "bell.slash",
                        description: Text(emptyStateDescription)
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(filteredNotifications) { notification in
                        NotificationRowView(
                            notification: notification,
                            onMarkAsRead: {
                                notificationStore.markAsRead(notification)
                            },
                            onDelete: {
                                notificationStore.delete(notification)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            notificationStore.markAsRead(notification)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                notificationStore.delete(notification)
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }

                            if !notification.isRead {
                                Button {
                                    notificationStore.markAsRead(notification)
                                } label: {
                                    Label("notifications.action.read", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                        .contextMenu {
                            if !notification.isRead {
                                Button {
                                    notificationStore.markAsRead(notification)
                                } label: {
                                    Label("notifications.action.markRead", systemImage: "checkmark")
                                }
                            }

                            Button(role: .destructive) {
                                notificationStore.delete(notification)
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .appScreenBackground()
        .navigationTitle("notifications.title")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if notificationStore.unreadCount > 0 {
                    Button("notifications.action.markAll") {
                        notificationStore.markAllAsRead()
                    }
                }

                if notificationStore.pushAuthorizationStatus != .authorized {
                    Button {
                        Task { await notificationStore.requestPushAuthorization() }
                    } label: {
                        Label("notifications.action.enablePush", systemImage: "bell.badge")
                    }
                }
            }
        }
        .task {
            notificationStore.loadNotifications()
            await notificationStore.refreshPushAuthorizationStatus()
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text("notifications.header.title")
                    .font(.title3.weight(.bold))

                Text("notifications.header.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    NotificationSummaryChip(
                        title: String(localized: "notifications.filter.all"),
                        value: notificationStore.notifications.count,
                        tint: .secondary
                    )
                    NotificationSummaryChip(
                        title: String(localized: "notifications.filter.unread"),
                        value: notificationStore.unreadCount,
                        tint: .accentColor
                    )
                }

                if notificationStore.pushAuthorizationStatus != .authorized {
                    Button {
                        Task { await notificationStore.requestPushAuthorization() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(Color.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("notifications.push.title")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text("notifications.push.subtitle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(AppTheme.Colors.mutedFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
        }
    }

    private var filterSection: some View {
        Section {
            Picker("notifications.filter.label", selection: $filter) {
                ForEach(NotificationReadFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: String(localized: "notifications.filter.all"), isSelected: selectedCategory == nil) {
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
            return String(localized: "notifications.empty.allTitle")
        case .unread:
            return String(localized: "notifications.empty.unreadTitle")
        case .read:
            return String(localized: "notifications.empty.readTitle")
        }
    }

    private var emptyStateDescription: String {
        switch filter {
        case .all:
            return String(localized: "notifications.empty.allDescription")
        case .unread:
            return String(localized: "notifications.empty.unreadDescription")
        case .read:
            return String(localized: "notifications.empty.readDescription")
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
            return String(localized: "notifications.filter.all")
        case .unread:
            return String(localized: "notifications.filter.unread")
        case .read:
            return String(localized: "notifications.filter.read")
        }
    }
}

private struct NotificationRowView: View {
    let notification: AppNotification
    let onMarkAsRead: () -> Void
    let onDelete: () -> Void

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
                        Text(String(format: String(localized: "notifications.scheduledAt"), scheduledAt.formatted(date: .omitted, time: .shortened)))
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if !notification.isRead {
                    Button {
                        onMarkAsRead()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "notifications.action.markRead"))
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "common.delete"))
            }
            .foregroundStyle(.secondary)
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

private struct NotificationSummaryChip: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        MacNotificationCenterScreen()
            .environment(store)
            .modelContainer(container)
    }
}

#endif
