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
- **맵 탭 디자인 1차 개선 완료** (2026-04-02)

## Current High-Level Goal

Finish LensNote into a coherent MVP/demo app:

- SwiftUI
- MVVM
- CoreML-based camera assistant
- composition and filter assistance
- map-based photo browsing

## Completed Work (2026-03-31 ~ 2026-04-01)

(이전 세션 — 요약만 유지)

- Camera save flow + map data flow 연결 (FetchPhotoPinsUseCase, LocationProvider, FilePhotoRepository)
- FloatingDockBar 카메라 라이브 뷰 숨김 처리
- 브랜치 정리 완료 (main only)

## Completed Work (2026-04-02)

맵 탭 디자인 전면 개선 — 3개 커밋:

1. **`feat(design): LensNoteTheme에 맵 하단 그라데이션 토큰 추가`** (`f486d8b`, Claude)
   - `Gradients.mapOverlayBottom` 토큰 추가 (opacity 0.55, FloatingDockBar 전환용)

2. **`feat(map): 맵 탭 디자인 전면 개선`** (`fd17ce8`, Claude)
   - PinAnnotationView: 라이브러리 핀 하드코딩 색상(`Color.accentColor`, `.white.opacity`) → LensNoteTheme 토큰
   - ClusterBadgeView: `.ultraThinMaterial` + `.secondary` → surfaceHighest + primary 테두리 + accentCyan 텍스트
   - SidePanelList: `.bar` 배경, `systemGray5`, `.secondary` → surfaceHigh + ultraThinMaterial, 테마 typography
   - PinCardView: source 뱃지(LENSNOTE/LIBRARY) 추가, 썸네일 44→56pt, cardLarge radius(28pt)
   - PermissionBannerView → PermissionOverlayView: 상단 배너에서 중앙 오버레이 카드로 격상
   - LoadingBannerView: accentCyan tint, 테마 typography
   - PinThumbnailView: `.secondary` → textTertiary
   - MapEmptyStateView 신규 추가: 빈 상태 안내 + "카메라로 이동" CTA
   - 맵 스타일: `.standard` → `.imagery` → **`.standard(pointsOfInterest: .excludingAll)`** (사용자 피드백 반영)
   - 하단 그라데이션 오버레이: 상단 제거, 하단만 dockTotalClearance+40 높이로 유지
   - SidePanelList + PinCardView 동시 표시 방지 (`selectedPin == nil` 조건)
   - PinCardView를 `safeAreaInset`에서 ZStack 오버레이로 이동 (FloatingDockBar 겹침 해소)

3. **`feat(map): 빈 상태 CTA에서 카메라 탭 전환 연결`** (`f0dc433`, kito2007)
   - MapView에 `onCameraTabTap: (() -> Void)?` 파라미터 추가
   - RootView에서 `selectedTab = .camera` 콜백 주입

## Known Architectural State

- Camera save flow → `SavePhotoUseCase` + `FilePhotoRepository` (JSON on disk).
- Map reads LensNote pins via `FetchPhotoPinsUseCase` from same repository, merged with PHPhotoLibrary pins.
- Photos survive app restarts as long as Documents directory is not cleared.
- `FloatingDockBar` is the custom tab navigation overlay in `RootView` — native TabView tab bar is not used.
- 맵 탭 서브뷰는 모두 `MapView.swift` 단일 파일 내 private struct로 정의 (파일 분리는 Milestone 2).

## Pending / Residual Risks

- `fetchAll()` is called synchronously on the main actor inside `loadLensNotePins()`. Fine for current dataset sizes; revisit if JSON file grows large.
- No migration logic: if `PhotoItem` schema changes, JSON decode fails silently (returns `[]`). Add version field before shipping.
- No automated test target exists. Manual QA is the only verification path.
- Runtime persistence validation (camera → save → force-quit → relaunch → map pin) still not formally confirmed.
- 맵 디자인 1차 개선 완료했지만 카메라/홈 화면 디자인 통일은 아직 미진행.

## Next Recommended Tasks (in priority order)

1. **디자인 개선 계속** — 카메라 라이브 뷰 어시스턴트 패널 + 구도 오버레이 정리
   - 담당: `lensnote-designer` → `lensnote-ios-engineer`
2. **Runtime validation** — camera → capture → save → force-quit → relaunch → map pin 확인 (수동 QA).
3. **카메라 온보딩 플로우 완성** (backlog P0) — 레퍼런스 사진 플로우, 분석 중 UX 등.
4. **Live guidance UX 안정화** (backlog P0).
5. **필터/컨셉 가시성** (backlog P1).

## Verification Status

- Camera save -> map data flow: implemented and build-verified
- FloatingDockBar hidden in camera live view: **real-device verified**
- FilePhotoRepository: implemented and build-verified
- Runtime persistence validation: not yet formally confirmed
- **맵 탭 디자인 개선: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4)
- 맵 탭 하드코딩 색상 제거 확인: `systemGray5`, `.yellow`, `.secondary`, `.bar` → grep 0건
- Branch state: main only, 3 commits ahead of origin

## Update Rule

At the end of each substantial work session, overwrite this file with the newest:

- completed work
- current blockers
- next exact task
- verification status
