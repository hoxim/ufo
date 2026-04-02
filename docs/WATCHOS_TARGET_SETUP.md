# watchOS Target Setup for UFO

This guide assumes the current repository layout:

- `ufo/AppCore/` for shared models, repositories, stores, and persistence
- `ufo/SharedUI/` for reusable UI pieces
- `ufo/watchOS/` for the standalone watch target UI

## Goal

Add a watchOS companion to the existing project without creating a second Xcode project.

## Xcode Steps

1. Open `/Users/hoxim/Developer/Xcode/ufo/ufo.xcodeproj` in Xcode.
2. Choose `File > New > Target`.
3. Open the `watchOS` section.
4. Pick the template for adding a watch app to an existing iOS app.
5. Name it something like `UFO Watch`.
6. Keep the interface SwiftUI.
7. Let Xcode create whatever watch-related targets the template needs for your Xcode version.

## First Files To Use

The repository already contains a minimal watch scaffold:

- `/Users/hoxim/Developer/Xcode/ufo/ufo/watchOS/ufoWatchApp.swift`
- `/Users/hoxim/Developer/Xcode/ufo/ufo/watchOS/App/WatchAppRootView.swift`
- `/Users/hoxim/Developer/Xcode/ufo/ufo/watchOS/Features/Home/WatchFeatureMenuView.swift`
- `/Users/hoxim/Developer/Xcode/ufo/ufo/watchOS/Features/Lists/WatchListsFeatureView.swift`

Start by assigning these files to the new watch target.

## Recommended Target Membership

Include first:

- `ufo/watchOS/`
- selected files from `ufo/AppCore/Models/` needed by watch features
- selected files from `ufo/AppCore/Repositories/` needed by watch features
- selected files from `ufo/AppCore/Stores/` only if they do not depend on iPhone-only or macOS-only code

Do not include first:

- `ufo/App/iOS/`
- `ufo/App/iPadOS/`
- `ufo/App/macOS/`
- `ufo/iOS/`
- `ufo/iPadOS/`
- `ufo/macOS/`
- large phone, iPad, or Mac screens that were built around heavier layouts

## Practical Rule

For watchOS, share data and logic first, not screens.

Good candidates to share:

- `SharedList`
- `SharedListItem`
- `SharedListRepository`
- parts of `SharedListStore` after checking dependencies

Bad candidates to share directly:

- complex editors
- split-view navigation
- toolbar-heavy Mac or iPad screens

## First Real watchOS Scope

Build only this flow at first:

1. Browse lists
2. Open one list
3. Toggle an item
4. Add a short item
5. Edit a short item title
6. Delete an item

If a feature needs a lot of typing, multiple modal layers, or advanced filtering, leave it out of version one.

## Suggested Implementation Order

1. Add the watch target in Xcode.
2. Assign the starter watch files to that target.
3. Make the watch target run the simplified sign-in and space picker flow first.
4. Connect list, incident, and mission loading.
5. Keep the first release read-focused and light.
6. Add write actions later where the watch interaction really benefits from them.
7. Only later think about broader feature parity.

## Sanity Check After Adding The Target

After the target exists, confirm:

- the iOS target still builds
- the watch target builds independently
- watch target membership does not include phone or Mac shell files
- no watch file imports iOS-only APIs
