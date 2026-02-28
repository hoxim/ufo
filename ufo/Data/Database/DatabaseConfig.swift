//
//  DatabaseConfig.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import Foundation
import Supabase

enum SupabaseConfig {
    private static var infoDictionary: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }
    
    static let url: URL = {
        guard let urlString = infoDictionary["SupabaseURL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not found in Info.plist")
        }
        return url
    }()
    
    static let anonKey: String = {
        guard let key = infoDictionary["SupabaseAnonKey"] as? String else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist")
        }
        return key
    }()
    
    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey,
        options: SupabaseClientOptions(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
