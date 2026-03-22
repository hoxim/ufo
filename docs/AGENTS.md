# AGENTS

This file is a lightweight operating guide for people and agents working in this repository.

## Product Intent

`ufo` is a shared life/work coordination app built around spaces. The current value comes from linking existing features into one ecosystem rather than adding many disconnected modules.

Core feature areas:
- Home dashboard
- Missions
- Notes
- Shared Lists
- Incidents
- Locations / Saved Places
- Routines
- Budget
- People / Spaces / Roles

## Current Priorities

1. Improve integration between features
2. Make UX more intuitive and consistent
3. Finish syncing settings and access control with Supabase
4. Keep iOS polished while gradually improving macOS structure
5. Add tests for sync, relations, and critical flows

## Working Principles

- Prefer native SwiftUI patterns unless a custom solution is clearly better
- Optimize for simple, obvious UX
- Reuse shared components when the same interaction appears in multiple places
- Do not mix unrelated responsibilities into one view
- Keep platform-specific wrappers separate when iOS and macOS diverge
- Avoid fragile UUID-based manual linking in UI
- Prefer graph-like relations between entities, but do not recurse automatically in UI

## Architectural Direction

### Navigation

- Keep one root `NavigationStack` per main tab on iOS
- Avoid nested root stacks inside feature screens
- Feature-to-feature navigation should feel continuous and reversible

### Data Flow

- Stores should own feature loading/sync flow
- Repositories should isolate Supabase access
- User preferences should move toward synced `UserSettings`
- Space-scoped access control should live in backend-backed role/group models

### UI

- Main tab bar should stay simple: `Home`, `People`, `Spaces`
- Feature screens can have their own local actions and search
- Modal headers should remain consistent: close on the left, confirm on the right
- Related content selectors should use the same menu-row pattern everywhere

## Important Areas To Respect

- `/Users/hoxim/Developer/Xcode/ufo/ufo/Features/Main`
- `/Users/hoxim/Developer/Xcode/ufo/ufo/Data/Stores`
- `/Users/hoxim/Developer/Xcode/ufo/ufo/Data/Repositories`
- `/Users/hoxim/Developer/Xcode/ufo/supabase/migrations`

## Known Active Themes

- Better related-content UX
- Role and visibility group architecture per space
- User settings sync
- Budget improvements
- macOS-specific cleanup where shared UI becomes awkward

## Build Check

Use:

```sh
xcodebuild -project /Users/hoxim/Developer/Xcode/ufo/ufo.xcodeproj -scheme ufo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## Documentation Companion Files

- `/Users/hoxim/Developer/Xcode/ufo/docs/TASKS.md`
- `/Users/hoxim/Developer/Xcode/ufo/docs/IDEAS.md`
- `/Users/hoxim/Developer/Xcode/ufo/docs/CHANGELOG.md`
- `/Users/hoxim/Developer/Xcode/ufo/docs/README.md`
