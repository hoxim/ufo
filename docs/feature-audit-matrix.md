# Feature Audit Matrix

Updated: 2026-04-10

## Summary

| Feature | iOS | iPadOS | macOS | watchOS | Data wiring | Theme status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Home / Summary | Yes | Yes | Yes | Partial | Local SwiftData reads | Shared `AppTheme` on primary platforms | watchOS uses feature menu instead of the dashboard grid |
| Notes | Yes | Yes | Yes | Yes | `NoteStore` / `NoteRepository` | Shared `AppTheme` on primary platforms | watchOS supports read/write |
| Missions | Yes | Yes | Yes | Yes | `MissionStore` / `MissionRepository` | Shared `AppTheme` on primary platforms | watchOS supports read/detail actions |
| Lists | Yes | Yes | Yes | Yes | `SharedListStore` / `SharedListRepository` | Shared `AppTheme` on primary platforms | watchOS supports item toggles |
| Incidents | Yes | Yes | Yes | Yes | `IncidentStore` / `IncidentRepository` | Shared `AppTheme` on primary platforms | watchOS supports status updates |
| Routines | Yes | Yes | Yes | Yes | SwiftData + `RoutineLog` flows | Shared `AppTheme` on primary platforms | watchOS supports routine logging |
| Budget | Yes | Yes | Yes | Yes | `BudgetStore` / `BudgetRepository` / `BudgetAnalyticsService` | Shared `AppTheme` chart palette added | watchOS is read-only in v1 |
| Notifications | Yes | Yes | Yes | Yes | `AppNotificationStore` | Shared `AppTheme` on primary platforms | watchOS surfaces notification list |
| Locations | Yes | Yes | Yes | Yes | `LocationStore` / `LocationRepository` | Shared `AppTheme` on primary platforms | watchOS is read-only |
| People | Yes | Yes | Yes | Yes | auth + profile/space queries | Shared `AppTheme` on primary platforms | macOS also has crew-specific views |

## Key Findings

- The core Apple platforms already follow a consistent `Screen -> Store -> Repository` pattern for the audited collaboration features.
- `Budget` was the main parity gap before this pass. It now exists across iOS, iPadOS, macOS and watchOS.
- Primary-platform visual consistency is now anchored on `AppTheme`, including a dedicated semantic chart palette for finance visuals.
- watchOS remains intentionally lighter than the other platforms. It exposes fast, read-focused budget access instead of full transaction editing.

## Follow-up Risks

- Remote parity for the new budget tables depends on backend availability for `budget_recurring_rules` and `budget_space_settings`. The app now degrades safely when those endpoints are unavailable, but server rollout still needs to happen.
- Existing non-budget features still deserve a deeper smoke-test pass in simulator/runtime, especially around empty states and destructive actions, even though their store/repository wiring exists.
- `Summary` is still conceptually a Home concern on watchOS rather than a standalone screen, so product parity there is behavioral, not visual.
