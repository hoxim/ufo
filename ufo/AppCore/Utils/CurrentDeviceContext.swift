import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum CurrentDeviceContext {
    static func make(authMethod: String = "password", approvedVia: String? = nil) -> DeviceSessionContext {
        DeviceSessionContext(
            platform: platformName,
            deviceName: deviceName,
            authMethod: authMethod,
            approvedVia: approvedVia
        )
    }

    private static var platformName: String {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #elseif os(macOS)
        "macOS"
        #else
        "unknown"
        #endif
    }

    private static var deviceName: String {
        #if os(iOS)
        UIDevice.current.name
        #elseif os(macOS)
        Host.current().localizedName ?? "Mac"
        #else
        ProcessInfo.processInfo.hostName
        #endif
    }
}
