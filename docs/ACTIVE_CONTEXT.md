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
- **카메라 디자인 전면 개선 완료** (2026-04-05)

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

맵 탭 디자인 전면 개선 — 3개 커밋 (요약만 유지):

- PinAnnotationView, ClusterBadgeView, SidePanelList, PinCardView, PermissionOverlayView, MapEmptyStateView 등 모든 맵 서브뷰 LensNoteTheme 토큰화
- 맵 스타일 `.standard(pointsOfInterest: .excludingAll)` 적용
- 빈 상태 CTA → 카메라 탭 전환 연결

## Completed Work (2026-04-05)

카메라 디자인 전면 개선 — stitch `ai_camera_assistant` 레퍼런스 엄격 준수:

1. **LensNoteTheme 토큰 추가**
   - `Colors.chipBorder` (white/10) — AI 분석 칩 테두리
   - `Colors.sideControlBg` (surfaceHigh/80) — 사이드 플로팅 버튼 배경
   - `Colors.shutterGlow` (primary/20) — 셔터 버튼 글로우
   - `Typography.chipLabel` (11px bold) — 칩 텍스트

2. **CameraLiveStepView 전면 재설계**
   - 기존 CameraAssistPanel + captureBar 제거
   - AI 분석 칩 3개 (Filter/ISO/Score): 좌측 상단, glass pill, uppercase tracking, 아이콘별 tertiary/primary/accentCyan
   - 하단 캡처 바: 레퍼런스 썸네일(원형, primary 테두리, REF 뱃지) + 셔터 버튼(white circle, primary glow) + AI 매직 버튼(hero gradient)
   - 사이드 플로팅 컨트롤: 맵(좌), 갤러리(우) — glass circle, shadow
   - AIDynamicAlignmentOverlay 신규: dashed circle (primary/40) + center dot + horizontal alignment line (tertiary/30)
   - Glass depth overlay: from-black/20 via-transparent to-black/40
   - GridOverlayView: white/10 opacity (stitch ref 준수)
   - FramingGuideOverlay: LensNoteTheme 토큰으로 전환 (success, accentCyan, warning 등)
   - ShutterButtonStyle 추가 (press scale animation)

3. **카메라 스텝 뷰 전체 테마 통일**
   - CameraSelectionStepView: Color 하드코딩 → LensNoteTheme 토큰, hero gradient border CTA, cameraBackground gradient
   - CameraConceptStepView: Color.black → surface, cardOverlay 배경, theme typography
   - CameraManualStepView: theme 슬라이더 (accentCyan tint), cardOverlay 배경, technical typography
   - CameraReferenceStepView: theme 색상/typography, accentCyan ProgressView tint
   - CameraCaptureResultStepView: cardLarge radius, theme 색상/typography, danger color for errors
   - CameraView successToast: success color, theme typography, glass background + shadow

4. **CameraBackButton 공통 컴포넌트화**
   - CameraButtonStyles.swift에 `CameraBackButton` struct 추가
   - 5개 스텝 뷰에서 중복 `backButton` private func 제거 → `CameraBackButton` 사용

5. **하드코딩 색상 완전 제거 확인**
   - `Color.black`, `.yellow`, `.secondary`, `.white.opacity` → grep 0건 (Camera 디렉토리)

## Known Architectural State

- Camera save flow → `SavePhotoUseCase` + `FilePhotoRepository` (JSON on disk).
- Map reads LensNote pins via `FetchPhotoPinsUseCase` from same repository, merged with PHPhotoLibrary pins.
- Photos survive app restarts as long as Documents directory is not cleared.
- `FloatingDockBar` is the custom tab navigation overlay in `RootView` — native TabView tab bar is not used.
- 맵 탭 서브뷰는 모두 `MapView.swift` 단일 파일 내 private struct로 정의 (파일 분리는 Milestone 2).
- CameraLiveStepView 사이드 버튼(map/photo)은 현재 no-op — 액션 연결은 추후 필요.

## Pending / Residual Risks

- `fetchAll()` is called synchronously on the main actor inside `loadLensNotePins()`. Fine for current dataset sizes; revisit if JSON file grows large.
- No migration logic: if `PhotoItem` schema changes, JSON decode fails silently (returns `[]`). Add version field before shipping.
- No automated test target exists. Manual QA is the only verification path.
- Runtime persistence validation (camera → save → force-quit → relaunch → map pin) still not formally confirmed.
- 카메라 사이드 버튼 액션 미연결 (map/photo library).

## Next Recommended Tasks (in priority order)

> **다음 세션 시작점**: 아래 1번부터 시작.

1. **Runtime validation** — camera → capture → save → force-quit → relaunch → map pin 확인 (수동 QA).
2. **카메라 온보딩 플로우 완성** (backlog P0) — 레퍼런스 사진 플로우, 분석 중 UX 등.
3. **Live guidance UX 안정화** (backlog P0).
4. **홈 화면 디자인 통일** — dark cinematic + cyan accent 언어 통일 (backlog 전체 디자인 개선 마지막 파트).
5. **필터/컨셉 가시성** (backlog P1).

## Verification Status

- Camera save -> map data flow: implemented and build-verified
- FloatingDockBar hidden in camera live view: **real-device verified**
- FilePhotoRepository: implemented and build-verified
- Runtime persistence validation: not yet formally confirmed
- **맵 탭 디자인 개선: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4)
- **카메라 디자인 개선: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4)
- 카메라 하드코딩 색상 제거 확인: `Color.black`, `.white.opacity` → grep 0건
- Branch state: main only
- Last handoff: 2026-04-05

## Update Rule

At the end of each substantial work session, overwrite this file with the newest:

- completed work
- current blockers
- next exact task
- verification status
