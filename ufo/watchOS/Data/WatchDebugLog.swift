#if os(watchOS)
import Foundation
import OSLog

enum WatchLog {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "UFO",
        category: "Watch"
    )

    static func msg(_ message: String) {
        logger.info("\(message)")
    }

    static func error(_ error: Error) {
        logger.error("\(error.localizedDescription) | \(String(describing: error))")
    }

    static func error(_ message: String) {
        logger.error("\(message)")
    }
}

#endif
