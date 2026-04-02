//
//  ImageUtils.swift
//  ufo
//
//  Created by Marcin Ryzko on 22/02/2026.
//

import Foundation
import CryptoKit

struct ImageUtils {
    /// Generates a unique filename for the given data using original filename to extract extension
    static func generateFileName(data: Data, originalName: String) -> String {
        let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        
        // Pobranie rozszerzenia (ostatni element po kropce)
        let ext = originalName.split(separator: ".").last.map(String.init) ?? "jpg"
        
        return "\(hash).\(ext)"
    }
}
