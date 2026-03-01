# Data Architecture (Local-First + Sync)

## Cel
- UI czyta stan z `Store` (jedno źródło prawdy dla widoków).
- `Repository` robi CRUD i synchronizację (`SwiftData` + `Supabase`).
- Gdy nie ma internetu: aplikacja działa na lokalnych danych.
- Gdy internet wraca: `Repository` wysyła `pendingSync` i pobiera najnowszy stan.

## Warstwy
- `Store`:
  - trzyma stan ekranów (`spaces`, `selectedSpace`, `missions`, `incidents`)
  - udostępnia metody wysokiego poziomu (`addMission`, `refreshRemote`, `syncPending`)
  - nie zna szczegółów SQL/Supabase
- `Repository`:
  - ma metody CRUD (`fetchAll`, `fetchById`, `createLocal`, `updateLocal`, `softDeleteLocal`)
  - robi mapowanie remote <-> local
  - obsługuje synchronizację i konflikt wersji

## Konwencje
- wszystkie modele współdzielone mają pola:
  - `version`
  - `updatedAt`
  - `updatedBy`
  - `deletedAt` (soft delete)
- lokalne zmiany ustawiają:
  - `pendingSync = true`
  - `version += 1`

## Sync flow
1. `Store` zapisuje lokalnie przez `Repository`.
2. `Store` wywołuje `syncPending()`.
3. `Repository` wysyła zmiany do Supabase.
4. `Repository` pobiera aktualny stan z Supabase i nadpisuje lokalne rekordy, jeśli zdalna wersja jest nowsza.

## Dodane klasy
- `MissionRepository` (rozszerzony o local-first CRUD)
- `IncidentRepository`
- `AssignmentRepository`
- `LinkRepository`
- `SpaceStore`
- `IncidentStore`
