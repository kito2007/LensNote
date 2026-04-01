# Active Context

## Current Project State

The project has:

- Claude project memory in `CLAUDE.md`
- role-based subagents for planning, design, engineering, simulator QA, and QA
- XcodeBuildMCP repo setup for simulator-driven testing
- MVVM explicitly documented as the required architectural pattern
- an external design reference folder resolved at `/Users/parktaeyeong/SideProjects/LensNote/stitch_ai_camera_assistant`
- camera save -> map data flow connected and persisted to disk (see "Completed Work" below)

## Current High-Level Goal

Finish LensNote into a coherent MVP/demo app:

- SwiftUI
- MVVM
- CoreML-based camera assistant
- composition and filter assistance
- map-based photo browsing

## Completed Work (2026-03-31)

Camera save flow and map experience have been connected:

1. `PhotoPinSource` enum added to `MapView.swift` — `.lensNote` and `.library` variants.
2. `PhotoPin.source: PhotoPinSource` field added. All construction sites updated.
3. `FetchPhotoPinsUseCase` created at `LensNote/Domain/UseCase/FetchPhotoPinsUseCase.swift`.
4. `MapViewModel` updated with a new `init(fetchPhotoPinsUseCase:)` and `loadLensNotePins()` method. The existing `override init()` (no-arg) is preserved for previews.
5. `loadPhotoPinsIfNeeded()` now calls `loadLensNotePins()` after PHPhotoLibrary load completes, and also in the permission-denied path.
6. `DIContainer.makeMapViewModel()` factory added — injects `FetchPhotoPinsUseCase` backed by the shared `LocalPhotoRepository`.
7. `RootView` updated to accept `DIContainer` and call `makeMapViewModel()` for the map tab.
8. `LensNoteApp` updated to pass `container` to `RootView`.
9. `LocationProvider` service created at `LensNote/Features/Camera/LocationProvider.swift` — wraps `CLLocationManager`, publishes `latestCoordinate: GeoCoordinate?`, handles `requestWhenInUseAuthorization`.
10. `CameraViewModel` updated: `locationProvider` injected, `startSessionIfNeeded` starts location updates, `stopSession` stops them, `saveCapturedImage` auto-resolves coordinate from `locationProvider.latestCoordinate`, sets `hasLocationWarning = true` when coordinate is nil.
11. `PinAnnotationView` redesigned with source-based visual differentiation: LensNote pins (56pt primary background, cyan glow on select, aperture badge) vs library pins (quieter 40pt surfaceHighest style).
12. `NSLocationWhenInUseUsageDescription` added to both Debug and Release build settings in `project.pbxproj`.
13. `locationWarningToast` added to `CameraView` — shown for 2.5s when `hasLocationWarning` is true, with `location.slash.fill` icon and `LensNoteTheme` tokens.
14. Build verified: `BUILD SUCCEEDED` on iPhone 17 Pro simulator (iOS 26.4).

## Completed Work (2026-03-31, session 2)

Persistent file-backed repository added:

15. `FilePhotoRepository` created at `LensNote/Domain/Repositories/FilePhotoRepository.swift`.
    - Writes `[PhotoItem]` as JSON to `<Documents>/photo_items.json` using `JSONEncoder`/`JSONDecoder`.
    - `save(_:)` reads the existing array, appends, and atomically writes back.
    - `fetchAll()` returns `[]` gracefully when the file does not yet exist.
    - `LocalPhotoRepository` preserved for preview/test use.
16. `DIContainer` updated: `self.photoRepository = FilePhotoRepository()` replaces `LocalPhotoRepository()`.
17. Build verified: `BUILD SUCCEEDED` on iPhone 17 Pro simulator (iOS 26.4).

## Known Architectural State

Camera save flow and map data flow are connected and now persistent:

- Camera save uses `SavePhotoUseCase` + `FilePhotoRepository` (JSON on disk).
- Map reads LensNote pins via `FetchPhotoPinsUseCase` from the same repository instance, merged with PHPhotoLibrary pins.
- Photos survive app restarts as long as the app's Documents directory is not cleared.

## Pending / Residual Risks

- `fetchAll()` is called synchronously on the main actor inside `loadLensNotePins()`. Fine for current dataset sizes; revisit if the JSON file grows large.
- No migration logic: if `PhotoItem` schema changes (new required fields), the JSON decode will fail silently (returns `[]`). Add a version field before shipping to users who already have data.
- `loadLensNotePins()` is called synchronously on the main actor. For large datasets this is fine with the current in-memory store, but requires a revisit if storage becomes async.
- Location permission dialog timing: `LocationProvider.start()` is called when the camera session starts. If the user denies location, `latestCoordinate` stays nil and all saves trigger the warning toast — this is intentional and correct behavior.
- `PinAnnotationView` source differentiation is functional but has not been reviewed for the full design spec polish (shadow intensity, animation timing). Recommend designer review.
- No automated test target exists. Manual QA is the only verification path.

## Next Recommended Tasks (in priority order)

1. **Runtime validation** — manually confirm: camera → capture → save → force-quit → relaunch → map tab shows LensNote pin. (QA agent had simulator coordinate issues last session; needs manual run.)
2. **Designer review** — ask `lensnote-designer` to review LensNote vs library pin visual differentiation in `PinAnnotationView`.
3. **Camera onboarding flow** (backlog P0) — concept input → live guidance → capture end-to-end without friction. Assign: `lensnote-designer` → `lensnote-ios-engineer` → `lensnote-simulator-qa`.
4. **Stabilize live guidance UX** (backlog P0) — guidance messaging should be calm and understandable.
5. **Filter/concept visibility** (backlog P1) — expose concept recommendation clearly in camera flow.

## Verification Status

- Camera save -> map data flow architecture: implemented and build-verified
- `NSLocationWhenInUseUsageDescription`: added to pbxproj
- `PhotoPinSource` enum and `PhotoPin.source`: implemented
- `FetchPhotoPinsUseCase`: implemented
- `LocationProvider`: implemented
- `hasLocationWarning` + location warning toast: implemented
- Build: SUCCEEDED (iPhone 17 Pro simulator, iOS 26.4) — both sessions
- `FilePhotoRepository`: implemented and build-verified
- `DIContainer` wired to `FilePhotoRepository`: implemented and build-verified
- Runtime persistence validation: not yet performed

## Update Rule

At the end of each substantial work session, overwrite this file with the newest:

- completed work
- current blockers
- next exact task
- verification status
