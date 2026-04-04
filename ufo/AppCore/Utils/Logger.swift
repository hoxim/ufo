//
//  Logger.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation
import OSLog

struct Log{

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "UFO", category: "App")

    static func msg(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.info("ℹ️ [\(fileName):\(line)] \(function) -> \(message)")
    }

    static func error(_ error: Error, file: String = #fileID, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.error("❌ [\(fileName):\(line)] \(function) -> \(detailedError(error))")
    }

    static func error(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.error("❌ [\(fileName):\(line)] \(function) -> \(message)")
    }

    static func dbError(_ operation: String, _ error: Error, file: String = #fileID, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.error("🗄️❌ [\(fileName):\(line)] \(function) [\(operation)] -> \(detailedError(error))")
    }

    private static func detailedError(_ error: Error) -> String {
        let nsError = error as NSError
        return [
            "localizedDescription=\(error.localizedDescription)",
            "type=\(String(describing: type(of: error)))",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)"
        ].joined(separator: " | ")
    }
}
