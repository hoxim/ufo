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
        var lines: [String] = []
        lines.append("localizedDescription=\(error.localizedDescription)")
        lines.append("type=\(String(describing: type(of: error)))")
        lines.append("domain=\(nsError.domain)")
        lines.append("code=\(nsError.code)")
        lines.append("debug=\(String(describing: error))")

        let mirror = Mirror(reflecting: error)
        if !mirror.children.isEmpty {
            let reflected = mirror.children.compactMap { child -> String? in
                guard let label = child.label else { return nil }
                return "\(label)=\(String(describing: child.value))"
            }
            if !reflected.isEmpty {
                lines.append("reflected={\(reflected.joined(separator: ", "))}")
            }
        }

        return lines.joined(separator: " | ")
    }
}
