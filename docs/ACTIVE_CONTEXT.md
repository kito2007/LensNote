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
- **CoreML 실시간 AI 파이프라인 구현 완료** (2026-04-06)
- **Live guidance UX 안정화 — 배너 노출 + 힌트 디바운스** (2026-04-17)

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

## Completed Work (2026-04-06)

CoreML 실시간 AI 추론 파이프라인 구현:

1. **MobileNetV2Service.swift** 신규 생성
   - Bundle에서 MobileNetV2.mlmodel lazy 로드 (VNCoreMLModel)
   - ImageNet classLabel → SceneType 매핑 테이블 (portrait/landscape/cityStreet/food/pet/night/etc)
   - `classify(pixelBuffer:) -> SceneClassificationResult?` — nonisolated, 세션 큐 직접 호출

2. **DeepLabV3Service.swift** 신규 생성
   - Bundle에서 DeepLabV3.mlmodel lazy 로드
   - CIContext 기반 513x513 리사이즈 (MainActor 의존 없음)
   - stepSize=8 stride 샘플링으로 성능 최적화
   - `segment(pixelBuffer:) -> SegmentationResult?` — 바운딩박스, 커버리지, 삼등분선 편차 포함

3. **AIInferenceAggregator.swift** 신규 생성
   - 순수 static 함수 집합 — 상태 없음
   - MobileNetV2 우선, DeepLabV3 person(index 15) 비율 5% 이상이면 portrait 오버라이드
   - inferenceScore = confidence * 0.6 + 구도점수 * 0.4
   - 삼등분선 편차 0.12 초과 시 방향 힌트 문구 생성

4. **RealTimeInferenceEngine.swift** 신규 생성
   - MobileNetV2Service + DeepLabV3Service 소유
   - baseInterval 0.5초 내장 스로틀러 (Date 비교 방식)
   - `analyze(pixelBuffer:) -> AIInferenceOutput?` — 두 모델 순차 실행 후 Aggregator 합성
   - 두 모델 모두 실패 시 nil 반환 (graceful fallback)

5. **CameraViewModel.swift** 수정
   - `inferenceEngine = RealTimeInferenceEngine()` 추가
   - `@Published sceneLabel`, `inferenceScore`, `coreMLSubjectBox`, `coreMLGuidanceHint` 추가
   - `captureOutput()` 내 `inferenceEngine.analyze(pixelBuffer:)` 호출 추가
   - `applyInferenceOutput(_ output:)` @MainActor 메서드 추가

6. **CameraLiveStepView.swift** 수정
   - `sceneLabel: String`, `inferenceScore: Double` 프로퍼티 추가 (기본값 있음)
   - FILTER 칩: conceptText 없을 때 sceneLabel 표시 (AI 장면 분류)
   - SCORE 칩: `max(inferenceScore, guidanceScore)` — CoreML 우선, Vision fallback

7. **CameraView.swift** 수정
   - CameraLiveStepView 호출부에 `sceneLabel:`, `inferenceScore:` 전달 추가

## Completed Work (2026-04-17 — onboarding flow)

레퍼런스 사진 온보딩 플로우 완성:

1. **CameraReferenceStepView.swift** 재작성
   - `ReferenceAnalysisStage` enum 도입 (idle/extractingTone/extractingColor/generatingPreset/completed).
   - 분석 진행률 카드: 3단계 체크리스트(ProgressView → checkmark.circle.fill 전환), 완료 후 생성된 FilterPreset 요약 섹션.
   - 프리셋 요약 바: 노출/대비/채도/온도/비네트 각각 중앙 기준 -1~1 슬라이더 시각화(accentCyan fill).
   - 빈 상태 안내 카드 추가 — "원하는 톤의 사진을 고르면 LensNote가 프리셋을 만들어요."
   - 완료 시 `"이 톤으로 촬영 시작"` hero gradient CTA 노출 (자동 점프 제거).
   - "다른 사진 선택" 라벨로 재선택 지원.

2. **CameraView.swift**
   - `isAnalyzing: Bool` → `referenceAnalysisStage: ReferenceAnalysisStage` + `referenceGeneratedPreset: FilterPreset?` state 교체.
   - `analyzeReferencePhotoAndMove()` 재작성: 650ms+650ms+500ms 단계적 스테이지 진행.
   - `onConfirm` 콜백에서 preset 적용 후 `.camera` 단계 전환.
   - `resetReferenceFlow()` 헬퍼: 뒤로가기 시 상태/이미지/picker 모두 초기화.
   - `selectedReferenceImage`를 `CameraLiveStepView`에 전달.

3. **CameraLiveStepView.swift**
   - `referenceImage: UIImage?` 프로퍼티 추가.
   - `referenceThumb`가 실제 이미지가 있으면 원형 크롭으로 표시, 없으면 기존 placeholder 아이콘 유지.

Build: ✅ BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.4).

## Completed Work (2026-04-17 — live guidance)

Live guidance UX 안정화 — CoreML/Vision 힌트를 화면에 노출:

1. **CameraViewModel.swift**
   - `@Published private(set) var activeGuidanceHint: String?` 추가 — UI에 실제 노출되는 최종 힌트.
   - CoreML 힌트 안정화 상태: `pendingCoreMLHint`, `pendingCoreMLHintSince`, `activeHintAppliedAt`.
   - 파라미터: `coreMLHintStabilityThreshold = 0.9s` (동일 힌트 ≥ 2프레임 지속), `coreMLHintMinDisplayDuration = 1.6s` (숨길 때 최소 표시 시간).
   - `updateActiveGuidanceHint()` 메서드 추가 — 우선순위: CoreML 힌트(디바운스 통과) → Vision `guidanceMessage`(CoreML 미활성 시 fallback).
   - `applyInferenceOutput`과 `applyGuidanceResult`(defer)에서 호출.
   - 초기 placeholder 메시지(`"컨셉을 입력하면 구도 안내를 시작해요."`)와 권한 에러 메시지는 필터링.

2. **CameraLiveStepView.swift**
   - `activeGuidanceHint: String?` 프로퍼티 추가.
   - 하단 캡처 바 위 `guidanceBanner(_:)` 배너 추가: sparkles 아이콘(accentCyan), 텍스트(bodyStrong), ultraThinMaterial capsule, chipBorder stroke.
   - `.spring(response: 0.38, dampingFraction: 0.88)` 애니메이션으로 asymmetric transition (insertion: opacity + offset, removal: opacity).
   - Preview "Guided"에 샘플 힌트 추가.

3. **CameraView.swift**
   - `activeGuidanceHint: viewModel.activeGuidanceHint` 전달.

Build: ✅ BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.4).

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
- 모델 파일이 번들에 없으면 `classify`/`segment` 모두 nil을 반환하고 기존 Vision 가이드로 graceful fallback된다 (크래시 없음).
- DeepLabV3 MLMultiArray 형상(shape)이 모델 버전에 따라 다를 수 있음. 현재 [513, 513] 가정. 실기기에서 동작 확인됨.

## Next Recommended Tasks (in priority order)

> **다음 세션 시작점**: 아래 1번부터 시작.

1. **홈 화면 디자인 통일** — dark cinematic + cyan accent 언어 통일 (backlog 전체 디자인 개선 마지막 파트).
2. **필터/컨셉 가시성** (backlog P1) — CameraConceptStepView에서 입력한 컨셉이 프리셋 추천에 반영되는 흐름을 시각적으로 더 명확히.
3. **Live guidance 실기기 튜닝** — 안정화 파라미터(0.9s stability / 1.6s min display)가 체감상 적절한지, 배너 위치가 캡처 버튼과 겹치지 않는지 확인.
4. **레퍼런스 분석 시간 체감 튜닝** — 1.8초가 적절한지, 단계 문구가 의미 있는지 실기기 확인.
5. **Runtime validation** — camera → capture → save → force-quit → relaunch → map pin 확인 (수동 QA).

## Verification Status

- Camera save -> map data flow: implemented and build-verified
- FloatingDockBar hidden in camera live view: **real-device verified**
- FilePhotoRepository: implemented and build-verified
- Runtime persistence validation: not yet formally confirmed
- **맵 탭 디자인 개선: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4)
- **카메라 디자인 개선: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4)
- 카메라 하드코딩 색상 제거 확인: `Color.black`, `.white.opacity` → grep 0건
- **CoreML AI 파이프라인: 실기기 검증 완료** — FILTER 칩 장면 분류 동적 변경 확인됨
- 모델 파일 번들 포함: Xcode 타겟 멤버 추가 완료
- **Live guidance UX: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4) — 실기기 체감 튜닝은 다음 세션에서
- **레퍼런스 온보딩 플로우: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4) — 실기기 체감 튜닝은 다음 세션에서
- Branch state: main only
- Last handoff: 2026-04-17

## Update Rule

At the end of each substantial work session, overwrite this file with the newest:

- completed work
- current blockers
- next exact task
- verification status
