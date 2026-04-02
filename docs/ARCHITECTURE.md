# UFO Architecture

## Folder Roles

- `ufo/AppCore/`: shared data, models, repositories, stores, persistence, settings, and non-UI helpers
- `ufo/SharedUI/`: reusable UI building blocks, theme, modifiers, and UI-focused extensions
- `ufo/App/`: app entry points and platform app shells
- `ufo/iOS/`, `ufo/iPadOS/`, `ufo/macOS/`: platform-specific navigation and full feature UI for the main app target
- `ufo/watchOS/`: standalone watch target UI and watch-specific data flow

## Placement Rules

- Put files in `AppCore/` when the code would make sense even without SwiftUI screens.
- Put files in `SharedUI/` when the code is visual and reusable across multiple features.
- Put files in `App/` when the code decides how the whole app starts or how a platform shell is composed.
- Put files in platform folders when the code is about layout, toolbars, navigation, interaction patterns, forms, details, or editors owned by that platform.

## Platform-First Workflow

- Fixing an iPhone-only layout bug should usually stay inside `ufo/iOS/`.
- Fixing an iPad-only layout bug should usually stay inside `ufo/iPadOS/`.
- Fixing a macOS-only navigation issue should usually stay inside `ufo/macOS/`.
- Fixing a watch-only interaction issue should usually stay inside `ufo/watchOS/`.
- Fixing data loading, sync, or persistence should usually land in `ufo/AppCore/`.
- Fixing a reusable visual primitive should usually land in `ufo/SharedUI/`.

## Current Structure

- Feature UI now lives in platform folders, even when some code is intentionally duplicated for clarity.
- `AppCore/` remains the shared backbone for models, repositories, stores, auth, sync, and persistence.
- `SharedUI/` remains the small shared layer for things like theme, modifiers, simple components, and navigation helpers.
- `iPadOS/` currently mirrors some iOS behavior, but keeps its own files so it can diverge cleanly into split-view or tablet-first layouts.
- `ufo/watchOS/` should stay focused on lightweight sign-in, space selection, read flows, and a few high-value quick actions.

## Guiding Rule

Prefer duplication over cross-platform screen indirection when that makes bugs easier to find.

Good:

- `ufo/iOS/Features/Incidents/...`
- `ufo/iPadOS/Features/Incidents/...`
- `ufo/macOS/Features/Incidents/...`

Avoid:

- one shared screen that branches repeatedly inside `body`
- shared feature folders that hide where a platform-specific bug really lives

## WatchOS Scope

The planned watchOS app should stay intentionally small:

- browse lists
- open a list
- add an item
- edit short item text
- toggle completed state
- delete an item

Avoid carrying over desktop or iPhone complexity into watchOS until the lightweight list flow feels great.
