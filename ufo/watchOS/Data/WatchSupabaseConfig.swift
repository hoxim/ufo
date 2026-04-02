#if os(watchOS)
import Foundation
import Supabase

enum WatchSupabaseConfig {
    private static let fallbackURLString = "https://lidynjdprwlkezhgfvvh.supabase.co"
    private static let fallbackAnonKey = "sb_publishable_KpEK57mFhSJde7kLqHhVzQ_-scvOF1C"
    private static let fallbackRedirectURLString = "ufo://auth-callback"

    private static var infoDictionary: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    static let url: URL = {
        let urlString = (infoDictionary["SupabaseURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedURLString = (urlString?.isEmpty == false ? urlString : nil) ?? fallbackURLString

        guard let url = URL(string: resolvedURLString) else {
            fatalError("Invalid SupabaseURL in watch configuration")
        }
        return url
    }()

    static let anonKey: String = {
        let key = (infoDictionary["SupabaseAnonKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (key?.isEmpty == false ? key : nil) ?? fallbackAnonKey
    }()

    static let redirectURL: URL = {
        let rawValue = (infoDictionary["SupabaseRedirectURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedRawValue = (rawValue?.isEmpty == false ? rawValue : nil) ?? fallbackRedirectURLString

        guard let redirectURL = URL(string: resolvedRawValue) else {
            fatalError("Invalid SupabaseRedirectURL in watch configuration")
        }
        return redirectURL
    }()

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey,
        options: SupabaseClientOptions(
            auth: .init(
                redirectToURL: redirectURL,
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}

#endif
