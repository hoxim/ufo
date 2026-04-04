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
        let nsError = error as NSError
        logger.error(
            "localizedDescription=\(error.localizedDescription) | domain=\(nsError.domain) | code=\(nsError.code)"
        )
    }

    static func error(_ message: String) {
        logger.error("\(message)")
    }
}

#endif
