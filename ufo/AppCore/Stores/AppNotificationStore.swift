import Foundation
import Observation
import SwiftData
import UserNotifications
#if os(iOS)
import UIKit
#endif

@MainActor
@Observable
final class AppNotificationStore {
    private let modelContext: ModelContext

    var notifications: [AppNotification] = []
    var currentSpaceId: UUID?
    var activeToast: AppToast?
    var pushAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var lastErrorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func bootstrap(spaceId: UUID?) async {
        currentSpaceId = spaceId
        loadNotifications()
        await refreshPushAuthorizationStatus()

        if notifications.isEmpty {
            addNotification(
                title: String(localized: "notifications.bootstrap.title"),
                body: String(localized: "notifications.bootstrap.body"),
                category: .system,
                priority: .passive,
                source: "bootstrap"
            )
        }
    }

    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        loadNotifications()
    }

    func loadNotifications() {
        do {
            let descriptor: FetchDescriptor<AppNotification>
            if let currentSpaceId {
                descriptor = FetchDescriptor<AppNotification>(
                    predicate: #Predicate<AppNotification> { notification in
                        notification.spaceId == nil || notification.spaceId == currentSpaceId
                    },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<AppNotification>(
                    predicate: #Predicate<AppNotification> { notification in
                        notification.spaceId == nil
                    },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
            }
            notifications = try modelContext.fetch(descriptor)
            lastErrorMessage = nil
        } catch {
            notifications = []
            lastErrorMessage = String(format: String(localized: "notifications.error.load"), error.localizedDescription)
        }
    }

    func addNotification(
        title: String,
        body: String,
        category: AppNotificationCategory,
        priority: AppNotificationPriority,
        spaceId: UUID? = nil,
        scheduledAt: Date? = nil,
        deepLink: String? = nil,
        source: String? = nil,
        toast: AppToast? = nil
    ) {
        let notification = AppNotification(
            spaceId: spaceId ?? currentSpaceId,
            title: title,
            body: body,
            category: category,
            priority: priority,
            scheduledAt: scheduledAt,
            deepLink: deepLink,
            source: source
        )

        modelContext.insert(notification)
        persistChanges()
        loadNotifications()

        if let toast {
            showToast(toast)
        }

        if let scheduledAt, scheduledAt > .now, (priority == .important || priority == .critical) {
            scheduleSystemNotification(for: notification)
        }
    }

    func markAsRead(_ notification: AppNotification) {
        guard notification.readAt == nil else { return }
        notification.readAt = .now
        persistChanges()
        loadNotifications()
    }

    func markAllAsRead() {
        notifications
            .filter { !$0.isRead }
            .forEach { $0.readAt = .now }
        persistChanges()
        loadNotifications()
    }

    func delete(_ notification: AppNotification) {
        modelContext.delete(notification)
        persistChanges()
        loadNotifications()
    }

    func showToast(title: String, message: String? = nil, style: AppToastStyle) {
        showToast(AppToast(title: title, message: message, style: style))
    }

    func dismissToast() {
        activeToast = nil
    }

    func refreshPushAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        pushAuthorizationStatus = settings.authorizationStatus
    }

    func requestPushAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshPushAuthorizationStatus()

            if granted {
                #if os(iOS)
                UIApplication.shared.registerForRemoteNotifications()
                #endif

                addNotification(
                    title: String(localized: "notifications.toast.enabled.title"),
                    body: String(localized: "notifications.toast.enabled.body"),
                    category: .system,
                    priority: .normal,
                    source: "push-permission",
                    toast: AppToast(
                        title: String(localized: "notifications.toast.enabled.title"),
                        message: String(localized: "notifications.toast.enabled.message"),
                        style: .success
                    )
                )
            } else {
                showToast(
                    title: String(localized: "notifications.toast.disabled.title"),
                    message: String(localized: "notifications.toast.disabled.message"),
                    style: .warning
                )
            }
        } catch {
            lastErrorMessage = String(format: String(localized: "notifications.error.enable"), error.localizedDescription)
            showToast(title: String(localized: "notifications.error.enableTitle"), message: error.localizedDescription, style: .error)
        }
    }

    private func showToast(_ toast: AppToast) {
        activeToast = toast

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard self?.activeToast?.id == toast.id else { return }
            self?.dismissToast()
        }
    }

    private func scheduleSystemNotification(for notification: AppNotification) {
        guard let scheduledAt = notification.scheduledAt else { return }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.badge = NSNumber(value: unreadCount + 1)

        let timeInterval = scheduledAt.timeIntervalSinceNow
        guard timeInterval > 1 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            guard let self, let error else { return }
            Task { @MainActor in
                self.lastErrorMessage = String(format: String(localized: "notifications.error.schedule"), error.localizedDescription)
            }
        }
    }

    private func persistChanges() {
        do {
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = String(format: String(localized: "notifications.error.save"), error.localizedDescription)
        }
    }
}
