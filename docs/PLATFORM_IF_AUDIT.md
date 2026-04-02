# Platform `#if` Audit

Audit refreshed on 2026-03-28 after moving feature screens into platform folders.

## Current hotspots

These areas still contain the highest concentration of platform-specific branching:

- `ufo/SharedUI/Extensions` - 33 markers
- `ufo/AppCore/Repositories` - 26 markers
- `ufo/SharedUI/Components` - 21 markers
- `ufo/App/Root` - 14 markers
- `ufo/iOS/Features/Notes` - platform-rich text support
- `ufo/iPadOS/Features/Notes` - platform-rich text support
- `ufo/macOS/Features/Notes` - platform-rich text support

## Highest-priority files to split next

- `ufo/AppCore/Repositories/AuthRepository.swift`
- `ufo/SharedUI/Extensions/Color+Extension.swift`
- `ufo/SharedUI/Extensions/View+Extension.swift`
- `ufo/App/Root/AppRoot.swift`
- `ufo/iOS/Features/Notes/PhoneNoteRichTextCodec.swift`
- `ufo/iPadOS/Features/Notes/PadNoteRichTextCodec.swift`
- `ufo/macOS/Features/Notes/MacNoteRichTextCodec.swift`
- `ufo/iOS/Features/Budget/PhoneBudgetFeatureSupport.swift`

## Interpretation

Not every `#if` is bad.

Acceptable places:

- small UI adapters in `SharedUI`
- platform API bridges in repositories or helpers
- top-level shell switching in `App/Root`
- file-level platform fences around platform-owned feature files

Best candidates for the next migration wave:

- editor flows that mix iOS and macOS layout decisions
- views that branch repeatedly inside `body`
- places where iPad still mirrors iPhone behavior too closely

## Migration rule going forward

- Keep platform branching near shell, navigation, or adapter boundaries.
- Prefer full platform-owned feature files over cross-platform feature screens.
- Share data in `AppCore/` and small reusable UI in `SharedUI/`, but keep screen-level code inside the owning platform folder.
