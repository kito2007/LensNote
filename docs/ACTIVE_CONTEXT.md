# Active Context

## Current Project State

The project has:

- Claude project memory in `CLAUDE.md`
- role-based subagents for planning, design, engineering, simulator QA, and QA
- XcodeBuildMCP repo setup for simulator-driven testing
- MVVM explicitly documented as the required architectural pattern
- an external design reference folder resolved at `/Users/parktaeyeong/SideProjects/LensNote/stitch_ai_camera_assistant`
- camera save -> map data flow connected and persisted to disk
- all feature branches merged and deleted — only `main` remains

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
16. `DIContainer` updated: `self.photoRepository = FilePhotoRepository()` replaces `LocalPhotoRepository()`.
17. Build verified: `BUILD SUCCEEDED` on iPhone 17 Pro simulator (iOS 26.4).

## Completed Work (2026-04-01)

Camera onboarding flow QA and tab bar fix:

18. Manual test session started — camera live view confirmed working on real device.
19. **Bug found & fixed**: `FloatingDockBar`가 카메라 라이브 뷰 하단 UI(어시스턴트 패널 + 셔터 버튼)를 가리는 문제.
    - `CameraView`에 `@Binding var isLiveCamera: Bool` 추가.
    - `step`이 `.camera`로 변경될 때 `isLiveCamera = true` 업데이트.
    - `RootView`에서 `isCameraLive`가 `true`이면 `FloatingDockBar` 렌더링 스킵.
    - 수정 파일: `LensNote/Features/Camera/CameraView.swift`, `LensNote/Application/RootView.swift`.
20. 브랜치 정리 완료:
    - `feature/design-system-v2`, `feature/stitch-home-redesign` 로컬/원격 모두 삭제.
    - 모든 작업 main에 머지 & 푸시 완료. 현재 `main` 브랜치만 존재.

## Known Architectural State

- Camera save flow → `SavePhotoUseCase` + `FilePhotoRepository` (JSON on disk).
- Map reads LensNote pins via `FetchPhotoPinsUseCase` from same repository, merged with PHPhotoLibrary pins.
- Photos survive app restarts as long as Documents directory is not cleared.
- `FloatingDockBar` is the custom tab navigation overlay in `RootView` — native TabView tab bar is not used.

## Pending / Residual Risks

- `fetchAll()` is called synchronously on the main actor inside `loadLensNotePins()`. Fine for current dataset sizes; revisit if JSON file grows large.
- No migration logic: if `PhotoItem` schema changes, JSON decode fails silently (returns `[]`). Add version field before shipping.
- `PinAnnotationView` source differentiation has not been reviewed for full design spec polish (shadow intensity, animation timing).
- No automated test target exists. Manual QA is the only verification path.
- Runtime persistence validation (camera → save → force-quit → relaunch → map pin) still not formally confirmed.

## Next Recommended Tasks (in priority order)

1. **디자인 전면 개선** (우선순위 상향) — 맵 화면부터 시작:
   - Map 탭: 핀 상세 카드, 빈 상태, 권한 안내 화면 디자인
   - Camera 라이브 뷰: 어시스턴트 패널 및 구도 오버레이 정리
   - 전체 화면 시각 언어 통일 (dark cinematic, cyan accent)
   - 담당: `lensnote-designer` → `lensnote-ios-engineer`
2. **Runtime validation** — camera → capture → save → force-quit → relaunch → map pin 확인 (수동 QA).
3. **카메라 온보딩 플로우 완성** (backlog P0) — 레퍼런스 사진 플로우, 분석 중 UX 등.
4. **Live guidance UX 안정화** (backlog P0).
5. **필터/컨셉 가시성** (backlog P1).

## Verification Status

- Camera save -> map data flow: implemented and build-verified
- `NSLocationWhenInUseUsageDescription`: added to pbxproj
- `PhotoPinSource` + `PhotoPin.source`: implemented
- `FetchPhotoPinsUseCase`: implemented
- `LocationProvider`: implemented
- `hasLocationWarning` + location warning toast: implemented
- `FilePhotoRepository`: implemented and build-verified
- `DIContainer` wired to `FilePhotoRepository`: implemented and build-verified
- FloatingDockBar hidden in camera live view: implemented, **real-device verified**
- Runtime persistence validation: not yet formally confirmed
- Branch state: main only, all work merged and pushed

## Update Rule

At the end of each substantial work session, overwrite this file with the newest:

- completed work
- current blockers
- next exact task
- verification status
