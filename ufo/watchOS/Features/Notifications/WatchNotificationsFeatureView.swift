#if os(watchOS)
import SwiftUI
import UserNotifications

struct WatchNotificationsFeatureView: View {
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingRequests: [UNNotificationRequest] = []
    @State private var errorMessage: String?
    @State private var resultMessage: String?

    var body: some View {
        List {
            Section("common.status") {
                LabeledContent("watch.notifications.permissions") {
                    Text(authorizationLabel)
                }
            }

            Section("watch.common.actions") {
                Button("watch.notifications.refresh") {
                    Task {
                        await refresh()
                    }
                }

                if authorizationStatus == .notDetermined {
                    Button("watch.notifications.requestPermission") {
                        Task {
                            await requestAuthorization()
                        }
                    }
                }

                Button("watch.notifications.sendTest") {
                    Task {
                        await scheduleTestNotification()
                    }
                }

                Button("watch.notifications.clearPending", role: .destructive) {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    Task {
                        await refresh()
                    }
                }
            }

            Section("watch.notifications.pending") {
                if pendingRequests.isEmpty {
                    Text("watch.notifications.pendingEmpty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pendingRequests, id: \.identifier) { request in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(request.content.title)
                            if !request.content.body.isEmpty {
                                Text(request.content.body)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("watch.notifications.note") {
                Text("watch.notifications.handoff")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let resultMessage {
                Section {
                    Text(resultMessage)
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("watch.notifications.title")
        .task {
            await refresh()
        }
    }

    private var authorizationLabel: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return String(localized: "watch.notifications.status.enabled")
        case .denied:
            return String(localized: "watch.notifications.status.disabled")
        case .notDetermined:
            return String(localized: "watch.notifications.status.notDetermined")
        @unknown default:
            return String(localized: "watch.notifications.status.unknown")
        }
    }

    private func refresh() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        pendingRequests = await center.pendingNotificationRequests()
        errorMessage = nil
    }

    private func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            resultMessage = String(localized: "watch.notifications.result.permissionsUpdated")
            await refresh()
        } catch {
            errorMessage = String(localized: "watch.notifications.error.requestPermission")
        }
    }

    private func scheduleTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "watch.notifications.test.title")
        content.body = String(localized: "watch.notifications.test.body")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            resultMessage = String(localized: "watch.notifications.result.testScheduled")
            await refresh()
        } catch {
            errorMessage = String(localized: "watch.notifications.error.scheduleTest")
        }
    }
}

#endif
