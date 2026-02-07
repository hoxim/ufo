//
//  AuthMock.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import Foundation
import SwiftData
import Supabase

@MainActor
struct AuthMock {

    // Funkcja fabryczna - tworzy gotowe repozytorium
    static func makeRepository(isLoggedIn: Bool = false) -> AuthRepository {

        // 1. Definiujemy pełny schemat (wszystkie modele SwiftData)
        let schema = Schema([
            UserProfile.self,
            Group.self,
            GroupMembership.self,
            GroupInvitation.self,
            Mission.self
        ])
        
        // 2. Konfiguracja In-Memory (dane znikają po zamknięciu Preview)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        
        // 3. Tworzymy kontener
        // Uwaga: W prawdziwym Preview warto ten kontener wstrzyknąć też do widoku przez .modelContainer()
        let container = try! ModelContainer(for: schema, configurations: [config])
        
        // 4. Inicjalizacja Repozytorium
        // Zakładamy, że masz singleton SupabaseConfig lub po prostu tworzysz klienta testowego
        let repo = AuthRepository(client: SupabaseConfig.client)
        
        // 5. Symulacja stanu
        if isLoggedIn {
            // Tworzymy UserProfile (zamiast starego User)
            let mockProfile = UserProfile(
                id: UUID(),
                email: "marcin@hoxim.com",
                fullName: "Commander Marcin",
                role: "admin"
            )
            
            // Wstawiamy do bazy in-memory
            container.mainContext.insert(mockProfile)
            
            // Ustawiamy stan repozytorium
            repo.currentUser = mockProfile
            repo.isLoggedIn = true
        } else {
            repo.currentUser = nil
            repo.isLoggedIn = false
        }
        
        return repo
    }
}
