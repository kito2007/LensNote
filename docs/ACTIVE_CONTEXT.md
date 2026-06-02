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
- **홈 화면 디자인 통일 — Quick Shot 수직 재배치 + Map Gallery preview + Recent Sessions 썸네일** (2026-04-18)
- **컨셉 입력 실시간 프리셋 미리보기 — PresetSummaryView 공용 추출 + suggestion chips + CTA 반영** (2026-04-18)
- **MapViewModel 서비스 분리 — GeocodingService + PhotoLibraryService 추출** (2026-04-18)
- **UX 결함 3건 + ShotStyle 룰셋 확장 완료** (2026-05-09)
- **ShotRecipe 풀 분석 — EXIF + Vision face geometry + DeepLabV3 person mask로 촬영 동작 역추출 + 자동 ShotStyle 라벨링(항공샷/거울샷/발끝샷/뒷모습)** (2026-05-09)
- **CameraReferenceStepView UX 결함 3건 수정 — Dynamic Island 헤더 충돌 / 분석 라벨 "중" 잔류 / CTA sticky 처리** (2026-05-09)
- **FloatingDockBar 가시성 — 카메라 sub-step 단위 제어 (selection만 dock 유지, 나머지 숨김)** (2026-05-09)
- **wideSelfie 신설 + cameraAngle fallback 보완 — 광각 셀피(coverage 10~40% 영역) 자동 라벨링** (2026-05-09)
- **ShotStyle 룰셋 미세 튜닝 + 한국어 조사 helper — 39장 CLI 일괄 검증 기반** (2026-05-09)
- **Kiro 평가 개선 스펙 도입 — `.kiro/specs/lensnote-evaluation-improvement` (12 요구사항)** (2026-06-01)
- **영속성 스키마 버전 + 마이그레이션 — PhotoStorageEnvelope / schemaVersion / os.Logger (Req 8)** (2026-06-01)
- **단위 테스트 타겟(LensNoteTests) 신설 + 핵심 도메인 테스트 13건 통과 (Req 9)** (2026-06-01)

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

## Completed Work (2026-04-18 — home screen)

홈 화면 디자인 전면 개선 — stitch `home_entry_point` 레퍼런스 준수:

1. **Quick Shot 카드 — 수직 재배치**
   - 기존 좌측 52pt 아이콘 + 우측 "Open Camera" 캡슐 버튼(horizontal)
   - 신규 vertical stack: 상단 52pt primary-container 아이콘 칩 → 제목 + 설명 → 하단 full-width "Open Camera" pill(surfaceHighest bg + primary/25 stroke + primary text)
   - 설명 문구를 "Manual pro controls with instant metadata logging."로 교체(stitch 원문)

2. **`mapGalleryCard` 신규 — Captured Moments 탭 가능 preview**
   - 기존 generic empty state(photo.on.rectangle.angled) 제거
   - dark map-gradient 배경 + 회전된 `map.fill` 워터마크(tertiary/10)
   - 좌상단 40pt 글래스 원형 칩(map.fill, tertiary tint, chipBorder stroke)
   - 하단 글래스 footer(surface/55 + ultraThinMaterial): "Captured Moments" 제목 + 3색(primary/tertiary/accentCyan) avatar stack + "128 PLACES" microLabel
   - 카드 전체가 Button → `onOpenMapGallery` 호출
   - 높이 170pt, cardLarge radius

3. **Recent Sessions — 썸네일 + gear 라벨로 스타일 통일**
   - 원형 아이콘 → 56pt rounded-14 그라데이션 썸네일(accentColor topLeading→bottomTrailing + photo.fill watermark)
   - 서브타이틀을 "오늘 · 4장" 등 한국어 날짜에서 카메라 gear 문구로 교체("Fujifilm X-T4 · 35mm f/2.0", "Sony A7IV · 24mm f/1.4", "Leica Q2 · 28mm f/1.7")
   - `RecentSession.Trailing` 열거형 추가: `.match(percent:)` / `.timeAgo(String)`, 각각 accent 색과 tertiary 색 매핑
   - Row 컨테이너: `surfaceLow` 카드 배경 + chevron.right 동반 표시

Build: ✅ BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.4).

## Completed Work (2026-04-18 — concept preset visibility)

필터/컨셉 가시성(backlog P1) — CameraConceptStepView 전면 개선:

1. **`FilterPreset.forConcept(_:)` static 메서드 신설**
   - CameraViewModel에 있던 private `presetForConcept(_:)` 삭제.
   - `FilterPreset`에 `.standard` 정적 상수 + `forConcept(_:)` 추가 — 뷰/뷰모델이 동일 룰 공유.
   - 키워드 셋 확장: 기존 무드/빈티지/따뜻/차가운 + 야경, 인물, 풍경까지 매핑.

2. **`PresetSummaryView.swift` 공용 컴포넌트 추출**
   - CameraReferenceStepView의 `presetSummary` + `presetBar` + `formattedValue` 로직을 이관.
   - `showsTitle` 옵션으로 제목 영역 토글 — 상위 뷰가 자체 제목을 노출하는 경우(컨셉 뷰) 대응.

3. **CameraReferenceStepView 정리**
   - 자체 `presetSummary`/`presetBar`/`formattedValue` 삭제.
   - 분석 완료 시 `PresetSummaryView(preset:)` 호출로 대체 — 레퍼런스/컨셉 두 흐름이 동일한 시각 언어.

4. **CameraConceptStepView 전면 재작성**
   - 헤더: "컨셉 입력" + 보조 카피 "컨셉 키워드에 맞춰 필터 프리셋을 실시간으로 추천해요."
   - **Suggestion chips 스크롤 행**: 야경/인물/풍경/무드/빈티지/따뜻한/차가운 — 탭 시 입력에 공백 조인해 누적, 이미 포함된 키워드는 accentCyan으로 활성 상태 표시.
   - **실시간 프리뷰 카드**: `trimmed.isEmpty`가 false면 등장. 매칭 시 "추천 프리셋" 라벨 + preset 이름 chip + `PresetSummaryView`(제목 없이 바만). 매칭 실패 시 안내 문구 + questionmark 아이콘.
   - **CTA 문구 동적 반영**: 매칭된 preset이 있으면 `"{preset.name}으로 시작"`, 아니면 기본 "카메라 시작". Hero gradient 배경 + elevated shadow로 다른 CTA와 일관.
   - 입력 변경 시 `.spring(0.38/0.88)` 애니메이션으로 카드/CTA 라벨 전환.

5. **자동 Xcode 동기화**
   - 프로젝트가 PBXFileSystemSynchronizedRootGroup 사용 중 → 신규 `PresetSummaryView.swift`는 target membership 조작 없이 자동 포함됨.

Build: ✅ BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.4).

## Completed Work (2026-05-09 — ShotRecipe 풀 분석)

레퍼런스 사진에서 **촬영 동작을 역추출**하는 새로운 분석 레이어. 톤/필터에 더해 "어떻게 자세를 잡고 어떤 렌즈로 찍었는가"까지 보여주는 게 목표. MZ 트렌드(항공샷·거울샷·발끝샷·뒷모습) 페르소나 검증을 위한 기능.

1. **`Domain/Entities/ShotRecipe.swift` 신규**
   - `ShotRecipe` struct: focalLength35mm/aperture/iso/shutterSpeed (EXIF), subjectCoverage/subjectVerticalPosition/subjectBoundingBox (Vision/DeepLab), faceYaw/facePitch/cameraAngle/gazeDirection (얼굴 geometry), horizonTilt, detectedStyle, styleConfidence.
   - enums: `VerticalPosition`, `CameraAngle` (highAngle/eyeLevel/lowAngle), `GazeDirection` (toCamera/awayFromCamera/unknown), `ShotStyle` (aerialSelfie/mirrorSelfie/footShot/backView/unknown), `ShotStyleConfidence` (high/medium/low).
   - `CodableRect` 래퍼(CGRect Codable 미지원 대응). Codable + Equatable 채택.

2. **`Features/Camera/ShotRecipeAnalyzer.swift` 신규** (12.9KB)
   - `analyze(imageData: Data) async -> ShotRecipe` 단일 공개 API. nonisolated.
   - 단계 A: ImageIO로 EXIF 파싱 (FocalLenIn35mmFilm/FNumber/ISOSpeedRatings/ExposureTime).
   - 단계 B: VNDetectHumanRectanglesRequest revision 2로 인물 박스 + Vision bottom-left → top-left 좌표 변환.
   - 단계 C: VNDetectFaceLandmarksRequest로 yaw/pitch → cameraAngle (pitch>0.3=low, <-0.2=high) + gazeDirection (|yaw|<0.25=toCamera).
   - 단계 D: 기존 `DeepLabV3Service` 재사용. Data → CGImage → CVPixelBuffer 변환 헬퍼 내장. dominantClass==15(person) 시 정밀 coverage.
   - 단계 E: 라벨링 룰 (우선순위) — aerialSelfie / mirrorSelfie / footShot / backView / unknown. 얼굴 미검출 시 bbox midY 0.35/0.65로 cameraAngle fallback.

3. **`Features/Camera/Views/ShotRecipeView.swift` 신규** (17.7KB)
   - `PresetSummaryView`와 형제 카드. cardOverlay + chipBorder + cardLarge radius.
   - 구조: 헤더(SHOT RECIPE + confidence dots) → 스타일 칩(SF Symbol + 한국어 부연) → cameraAngle/gazeDirection 행 → subjectCoverage 단방향 progress 바(accentCyan) → 메타데이터 단일 행(focal · f/X · ISO · shutter · horizon).
   - ShotStyle별 색상: aerialSelfie=accentCyan, mirrorSelfie=primary, footShot=tertiary, backView=warning, unknown=textTertiary.
   - Confidence dots: high=success(green), medium=accentCyan, low=textTertiary.
   - nil 필드 자동 숨김. 모든 필드 nil + unknown이면 "분석 결과 없음" 안내.
   - Preview 4종 (각 ShotStyle별 + 빈 케이스).

4. **`Features/Camera/Views/CameraReferenceStepView.swift` 통합**
   - `ReferenceAnalysisStage`에 `case extractingShot` 추가 (4번째 단계).
   - `generatedRecipe: ShotRecipe?` 프로퍼티 추가, `PresetSummaryView` 아래 Divider + `ShotRecipeView` 노출.
   - `confirmButtonLabel` 계산 프로퍼티: detectedStyle ≠ .unknown이면 "이 톤 + {스타일}으로 촬영 시작", unknown이면 기존 문구. CTA 라벨 .animation으로 부드럽게 전환.

5. **`Features/Camera/CameraView.swift` 통합**
   - `@State referenceImageData: Data?` 추가 — picker raw Data 보관(EXIF 보존, 이미 `loadTransferable(type: Data.self)`로 받고 있음).
   - `@State referenceGeneratedRecipe: ShotRecipe?` 추가.
   - `analyzeReferencePhotoAndMove(image:)` → `(image:data:)`로 변경. 4단계 흐름: tone(650ms) → color(650ms) → preset(500ms) → extractingShot 단계에서 `Task.detached(priority: .userInitiated)` 내에서 `ShotRecipeAnalyzer().analyze(imageData:)` 호출 → `await MainActor.run`으로 결과 세팅 → completed.
   - `resetReferenceFlow()`에서 `referenceImageData`, `referenceGeneratedRecipe` nil 초기화.

Build: ✅ BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.4.1).

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
- 시뮬레이터에서 `VNDetectFaceLandmarksRequest`의 yaw/pitch가 nil로 나올 수 있음 — 이 경우 ShotRecipeAnalyzer가 사람 박스 위치 기반 cameraAngle 추정으로 fallback. 실기기 검증 필요.
- `horizonTilt`는 항상 nil (Vision에 수평선 감지 API 없음). 별도 모델 또는 CoreMotion 기반 확장 여지.
- 레퍼런스 분석 중 사용자가 뒤로가기 하면 `Task` 내부의 ShotRecipeAnalyzer가 취소되지 않고 끝까지 실행됨 — UI에는 반영 안 됨(`referenceAnalysisStage`가 .idle로 리셋된 상태). 불필요한 CPU 사용 정도. 취소 패턴 도입은 별도 작업.

## Completed Work (2026-05-09 — UX fixes + ShotStyle expansion)

실기기 UX 결함 3건 수정 + ShotStyle 룰셋 확장:

1. **레퍼런스 사진 미리보기 짤림 수정 (CameraReferenceStepView.swift)**
   - `scaledToFill() + .frame(height: 200) + .clipped()` → `scaledToFit() + .frame(maxHeight: 300)`.
   - 세로 인물 사진 머리/하체 짤림 해소. background(cardOverlay)로 letterbox 영역 처리.

2. **CTA FloatingDockBar 가림 해소 (RootView.swift + CameraReferenceStepView.swift)**
   - 옵션 1 채택: RootView TabView에 `.safeAreaInset(edge: .bottom, spacing: 0)` 추가.
   - `isCameraLive == false`일 때만 `dockTotalClearance(116pt)` 투명 spacer 삽입.
   - 모든 탭의 `safeAreaInset` CTA 자동 보호. 카메라 라이브 뷰 시 불필요 인셋 없음.
   - CameraReferenceStepView CTA에 `.padding(.bottom, xs + dockTotalClearance)` 추가 명시 유지.

3. **unknown 안내 문구 수정 (ShotRecipeView.swift)**
   - "분석 중 — 더 선명한 레퍼런스를 골라보세요" → "스타일 미확정 — 더 선명한 레퍼런스를 골라보세요".

4. **ShotStyle 신규 케이스 (ShotRecipe.swift)**: classicSelfie / landscape / closeUp 추가.

5. **ShotRecipeAnalyzer 룰 갱신 (ShotRecipeAnalyzer.swift)**
   - 8단계 우선순위: aerialSelfie → mirrorSelfie → classicSelfie → footShot → backView → closeUp → landscape → unknown.
   - classicSelfie: gaze==.toCamera && angle==.eyeLevel && coverage >= 0.40.
   - closeUp: coverage >= 0.65 (위 규칙 미해당). confidence .medium 고정.
   - landscape: coverage == nil || < 0.05. EXIF focalLength 있으면 .high.

6. **ShotRecipeView 신규 케이스 매핑 + 색상 충돌 조정 (ShotRecipeView.swift)**
   - classicSelfie: primary(Blue) / mirrorSelfie: warning(Gold) / backView: danger(Red) — 기존 mirrorSelfie=primary 변경으로 충돌 해소.
   - landscape: success(Green) / closeUp: tertiary(Violet).

7. **confirmButtonLabel 신규 케이스 (CameraReferenceStepView.swift)**: classicSelfie="셀피", landscape="풍경샷", closeUp="근접샷".

Build: ✅ BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.4.1)

## Completed Work (2026-05-09 — dock visibility per sub-step)

카메라 sub-step 단위 FloatingDockBar 가시성 제어:

1. **`CameraView.swift`**
   - `isLiveCamera: Binding<Bool>` → `hidesFloatingDock: Binding<Bool>` 이름 변경 (의미 명확화).
   - `onChange(of: step)`: `isLiveCamera = (newStep == .camera)` → `hidesFloatingDock = (newStep != .select)`.
   - selection 진입점에서는 dock 유지, concept/manual/reference/live/result 모든 sub-step에서 dock 숨김.

2. **`RootView.swift`**
   - `@State isCameraLive` → `@State cameraHidesDock`.
   - `shouldHideDock: Bool` computed property 추가: `selectedTab == .camera && cameraHidesDock`.
   - `safeAreaInset` 조건 + dock 오버레이 조건 모두 `shouldHideDock`으로 통일.
   - 다른 탭(Home/Map/Profile)이 활성이면 `shouldHideDock`이 항상 false → dock 정상 표시 보장.

3. **`CameraReferenceStepView.swift`**
   - CTA `.safeAreaInset` padding: `.padding(.bottom, xs + dockTotalClearance)` → `.padding(.bottom, xs)`.
   - dock이 숨겨진 상태이므로 116pt 잉여 패딩 제거. 시스템 `.bottom` safeAreaInset이 home indicator 처리.

Build: ✅ BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.4.1).

## Completed Work (2026-05-09 — wideSelfie + cameraAngle fallback)

실기기 테스트에서 정면 셀피(coverage 22%, focal 24mm)가 unknown으로 떨어진 사각지대 발견. 한국 MZ "와이드 셀피" 트렌드 — 광각으로 본인+배경을 함께 담는 구도.

1. **`ShotStyle` enum에 `wideSelfie` 추가** (ShotRecipe.swift)
2. **`estimateCameraAngle` fallback 보완** (ShotRecipeAnalyzer.swift): midY 0.35~0.65 → `nil` 대신 `.eyeLevel`. face pitch가 nil인 경우(시뮬레이터/일부 실기기)에도 cameraAngle이 결정되도록.
3. **wideSelfie 룰** (단계 E 우선순위 3번, classicSelfie 앞): `gaze == .toCamera && cameraAngle ∈ [eyeLevel, highAngle] && 0.10 ≤ coverage < 0.40 && (focal == nil || focal ≤ 28)`. classicSelfie의 0.40 상한과 깔끔한 boundary.
4. **`Colors.primaryLight` 신규 토큰** (LensNoteTheme.swift): `Color(red: 0.392, green: 0.710, blue: 0.965)` — primary 계열이지만 한 단계 밝아 "넓고 개방적" 느낌. wideSelfie 칩 색상.
5. **ShotRecipeView 매핑**: "WIDE SELFIE" 칩, `figure.arms.open` 심볼, "광각 셀피 — 본인 + 배경" 부연. Preview 1종 추가.
6. **CameraReferenceStepView**: confirmButtonLabel switch에 wideSelfie 케이스 추가.

Build: ✅ BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.4.1).

## Completed Work (2026-05-09 — 룰셋 미세 튜닝 + 한국어 조사)

39장 KakaoTalk 사진을 swift CLI 스크립트로 일괄 분석한 결과 31/39(79%) 정상 라벨링, 8장 unknown. 4가지 패턴별 임계값 fix:

1. **wideSelfie focal 조건 완화** (ShotRecipeAnalyzer.swift): `focal ≤ 28` → `focal ≤ 50`. 표준/망원 화각(35mm·50mm) 셀피도 wideSelfie로 잡힘. cameraAngle 조건도 `eyeLevel || highAngle` → `nil이 아닌 모든 각도`로 확장 (lowAngle 셀피 케이스). Confidence는 focal ≤ 28 → high, > 28 → medium, nil → low로 차등.

2. **landscape 임계값 완화**: `coverage < 0.05` → `coverage < 0.10`. 사람 7~9% 작게 들어간 여행 풍경/배경 사진까지 풍경으로 라벨링.

3. **mirrorSelfie 임계값 완화**: `coverage ≥ 0.35` → `coverage ≥ 0.15`. 멀리서 거울로 본인 찍는 와이드 거울샷 잡힘. `gaze=awayFromCamera + eyeLevel` 조합 자체가 강한 시그널이라 false positive 적음.

4. **한국어 조사 helper 신설** (CameraReferenceStepView.swift):
   ```swift
   private func josa(after word: String) -> String {
       guard let last = word.unicodeScalars.last,
             last.value >= 0xAC00 && last.value <= 0xD7A3 else { return "으로" }
       return ((last.value - 0xAC00) % 28 != 0) ? "으로" : "로"
   }
   ```
   유니코드 한글 음절 종성 비트 판별. "와이드 셀피으로/정면 셀피으로/풍경으로" → "와이드 셀피로/정면 셀피로/풍경으로"로 자연스러워짐.

5. **ShotRecipeView koreanDescription 통일**: "광각 셀피" → "와이드 셀피"로 confirmButtonLabel과 일치.

검증: 39장 CLI 시뮬레이션 결과 8장 unknown이 모두 의미 있는 라벨로 분류됨 — wideSelfie 3장(#15, #23, #32), landscape 6장(#3, #4, #10, #11, #13, #30), mirrorSelfie 1장(#31).

Build: ✅ BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.4.1).

## Completed Work (2026-06-01 — Kiro 스펙 기반 저위험 작업)

Kiro AI가 작성한 평가/개선 스펙(`.kiro/specs/lensnote-evaluation-improvement`)을 도입하고, 그중 리스크 낮은 기술 기반 작업 2건을 우선 완료. 방향성: 카메라 UX는 사용자에게 불필요한 단계 제거(Req 12 플로우 간소화) — 다음 작업.

1. **Kiro 스펙 도입 (커밋 4b573c8)**
   - requirements.md(12 요구사항, EARS) / design.md(8 correctness property) / tasks.md(14 태스크 + wave 그래프).
   - 코드가 스펙 작성 시점보다 앞서 있음: **Req 7(MapView 분리)은 이미 완료** — `Features/Map/Views/`에 PinAnnotationView/ClusterBadgeView/SidePanelList/PinCardView/PermissionOverlayView/MapEmptyStateView/PinThumbnailView 분리됨, MapView.swift 300줄.

2. **영속성 스키마 버전 + 마이그레이션 (Req 8, 커밋 f1a6b08)**
   - `PhotoStorageEnvelope { schemaVersion: Int; items: [PhotoItem] }`, currentVersion=1. 저장 시 최상위에 schemaVersion 기록.
   - `FilePhotoRepository.fetchAll()`: envelope 디코딩 → 버전 검사. 구버전 bare array(v0) 자동 마이그레이션. 디코딩 실패/미래 버전은 빈 배열 + `os.Logger` 에러 (throw 대신 graceful fallback). **fetchAll이 non-throwing으로 변경**됨(프로토콜은 throws 유지, 비-throwing 오버라이드).
   - `PhotoItem`에 `shotStyle: ShotStyle?`, `filterPresetName: String?` 추가(optional → 구버전 JSON 디코딩 호환). 메모버와이즈 init 명시.
   - `SavePhotoUseCase.execute`에 shotStyle/filterPresetName 파라미터(기본 nil). `CameraViewModel.saveCapturedImage`가 적용된 preset 이름 기록.

3. **단위 테스트 타겟 + 도메인 테스트 (Req 9, 커밋 20a0675)**
   - `LensNoteTests` 유닛 테스트 타겟 신설 (xcodeproj objectVersion 77 수동 편집 + 공유 스킴 `LensNote.xcscheme` TestAction). PBXFileSystemSynchronizedRootGroup이라 `LensNoteTests/` 폴더 파일 자동 포함.
   - swift-testing 13개 테스트(4 suite): AIInferenceAggregator(0/0, 1/1, nil/nil) · ShotRecipeAnalyzer.classifyStyle(aerial/mirror/landscape/unknown) · FilterPreset.forConcept(매핑/빈/미매핑) · FilePhotoRepository(라운드트립/빈상태/구버전 마이그레이션).
   - 테스트 seam 2건: `ShotRecipeAnalyzer.classifyStyle` private→static internal, `FilePhotoRepository.init(fileURL:)` 주입.

Build: ✅ BUILD SUCCEEDED / Test: ✅ 13 tests passed (iPhone 17 Pro Simulator).

## Completed Work (2026-06-01 — 라이브 코칭 Req 1)

레퍼런스 ShotRecipe ↔ 라이브 프레임 비교 델타 코칭 구현. 3개 커밋 분리.

1. **LiveCoachingEngine (커밋 935aa6f)** — 순수 함수 `enum`. `compare(reference:live:) -> LiveCoachingDelta?`.
   - coverage: `(live - ref) >= +0.15` "더 멀리", `<= -0.15` "더 가까이". `coverageThreshold = 0.15`.
   - cameraAngle 보정(현재→목표): highAngle→eyeLevel "내려주세요", lowAngle→eyeLevel "올려주세요", eyeLevel→highAngle "위로 올려주세요", eyeLevel→lowAngle "아래로 내려주세요" + high↔low 2쌍. 물리적 UX 방향(현재 앵글을 목표로 보정)으로 해석, 코드 주석 명시.
   - reference nil → 전체 nil(Req 1.5), 각 축 nil이면 해당 메시지 생략(Req 1.8).
   - `LiveCoachingDelta { coverageMessage, angleMessage, primaryMessage(coverage 우선), isEmpty }`.
   - property 테스트 7건(`LensNoteTests/LiveCoachingEngineTests`): Property 1 coverage 정확성(100회), Property 2 레퍼런스 없음(100회), 임계 컷오프, 앵글 매핑/동일/nil.
2. **CameraViewModel 통합 (커밋 2da4e16)** — `referenceRecipe`(@Published) + `setReferenceRecipe(_:)`. `applyInferenceOutput`이 라이브 추론(`AIInferenceOutput.subjectCoverage`/`subjectBoundingBox`)을 ShotRecipe로 환산 → `compare` → `coachingMessage`. `updateActiveGuidanceHint`에서 `primaryHint = coachingMessage ?? coreMLGuidanceHint`로 기존 0.9s/1.6s 디바운스를 그대로 통과해 **기존 글래스 배너 재사용**(별도 프로퍼티 안 만듦 → task 3.5도 충족). CameraView 레퍼런스 onConfirm에서 set, 컨셉/수동/reset에서 nil로 코칭 범위 한정.
   - ⚠️ **라이브 경로에 face landmark 없음 → live `cameraAngle` 항상 nil → 실제로는 coverage 코칭만 동작**(앵글 코칭은 Req 10 pitch 연동 필요).
3. **저장 ShotStyle 연결 (커밋 f2108e5)** — `saveCapturedImage`가 `referenceRecipe?.detectedStyle`을 `SavePhotoUseCase.execute(shotStyle:)`로 전달 → `PhotoItem.shotStyle` 영속화.

tasks.md task 3(3.1~3.5) 전체 체크 완료.
Build: ✅ BUILD SUCCEEDED / Test: ✅ 20 tests passed (iPhone 17 Pro Simulator). 라이브 코칭 실기기 확인 완료(사용자).

## Completed Work (2026-06-01 — 카메라 진입 간소화 Req 12 + 접근성 Req 4)

사용자 확정 방향(불필요한 단계 제거) + UX 결정(풀스크린 라이브 뷰 + 복귀 버튼 / 인라인 버튼 3개 + 시트). 2커밋.

1. **진입 즉시 라이브 뷰 + 인라인 셋업 시트 (커밋 7abd1a9)**
   - `CameraSelectionStepView` 제거(파일 삭제). `CameraInputMode`에서 select/photo/text/manual 제거 → `camera`/`result`만. 진입 시 바로 `.camera`.
   - 레퍼런스/컨셉/수동을 라이브 뷰 위 `.sheet(item: CameraSetupSheet)`로 전환. 기존 step 뷰 3종(Reference/Concept/Manual)을 시트 콘텐츠로 **그대로 재사용**.
   - `CameraLiveStepView`: 인라인 셋업 툴바(레퍼런스/컨셉/수동 3버튼, bottomCaptureBar 위) 추가. topBar back 버튼 → `house.fill` + `onExit`(홈 복귀). `onTapReference/Concept/Manual` 콜백 추가.
   - **dock**: 카메라 탭은 항상 풀스크린 → `RootView.shouldHideDock = (selectedTab == .camera)`로 단순화. `cameraHidesDock` 상태/`hidesFloatingDock` 바인딩 **완전 제거**(TabView onAppear 타이밍 의존 제거). `CameraView(onExit:)`가 `selectedTab = .home`으로 복귀.
   - 진입 경로별 `setReferenceRecipe` 호출 유지(레퍼런스 onConfirm→set, 컨셉/수동/reset→nil).
2. **접근성 식별자 (커밋 직후 — Req 4 / task 1.3)**
   - CameraLiveStepView: `camera.shutter`/`ai_magic`/`guidance_banner`/`side_map`/`side_gallery`/`select_reference`/`select_concept`/`select_manual`.
   - FloatingDockBar: `dock.tab.home/camera/map/profile`(`AppTab.identifierKey` 추가). MapView 단일 핀: `map.pin.<id>`.

tasks.md task 1(1.1~1.3) 전체 체크. Build: ✅ BUILD SUCCEEDED / Test: ✅ 20 passed.
⚠️ 시뮬레이터는 카메라 피드 없음 → 라이브 뷰/시트 체감·홈 복귀 흐름 실기기 검증 필요.

## Completed Work (2026-06-01 — 캡처 결과 카드 Req 2)

저장 후 라이브 뷰로 즉시 복귀하던 흐름 → 결과 카드로 전환. 2커밋(78e248a 본체 + 콜드스타트 포커스 fix).

1. **CaptureResultInfo + 역지오코딩** — `CaptureResultInfo`(photoID/thumbnail/placeName/preset/shotStyleLabel/coordinate/canNavigateToMap). `CameraViewModel.captureResult`(@Published). `saveCapturedImage` 성공 시 결과 구성 + `startPlaceNameResolution`(CLGeocoder, `withTaskGroup`로 지오코딩 vs 3s 타임아웃 경합 → 실패 "위치명을 불러올 수 없음", 좌표 nil "위치 정보 없음"). `clearCaptureResult()`로 다시찍기/새촬영 시 초기화.
2. **결과 카드 UI** — `CameraCaptureResultStepView`: result nil=저장 전 확인(+실패 시 에러/재시도, capturedImage 유지 Req 2.4), result 존재=카드(썸네일/위치/프리셋/ShotStyle + "새 촬영"/"지도에서 보기"). 좌표 nil이면 지도 버튼 비활성(Req 2.3). `ShotStyle.koreanDescription/displayLabel` internal 승격해 재사용. 사용 안 하게 된 successToast/showTransientSuccess 제거.
3. **지도 이동(Req 2.2)** — `CameraView.onNavigateToMap(UUID)` → `RootView`가 지도 탭 전환 + `MapViewModel.requestSelection(id)`. MapVM: `loadLensNotePins()`로 방금 저장 핀 갱신 → 해당 핀 `selectedPin` + `focusCoordinate` 발행(없으면 `pendingSelectionID` 보류 후 로드 시 적용). MapView `focusCamera(on:)`로 카메라 이동(onChange + .task 양쪽). **PhotoPin.id == PhotoItem.id** 활용.

tasks.md task 5(5.1) 체크. Build: ✅ / Test: ✅ 20 passed.
⚠️ 시뮬레이터 카메라 피드 없음 → 결과 카드 표시·역지오코딩·지도 이동 실기기 검증 필요.

## Completed Work (2026-06-01 — 카메라 사이드 버튼 Req 3)

라이브 뷰 no-op 사이드 버튼에 액션 연결. 1커밋.
- `CameraLiveStepView`: `onMapTap`/`onGalleryTap` 콜백 + `sideButton(action:)` 연결.
- 지도 버튼 → `onOpenMap`(RootView가 `selectedTab=.map`, 핀 선택 없음, Req 3.1).
- 갤러리 버튼 → `.photosPicker(isPresented:)` 직접 표시(Req 3.2). 선택 시 `referencePickerItem` onChange가 `activeSetupSheet=.reference`로 분석 시트 오픈(Req 3.3), 취소 시 라이브 유지(Req 3.4). 시트 내 PhotosPicker와 동일 바인딩 공유.
- Req 3.5: PHPicker는 out-of-process라 사진 권한 불필요 → 거부 시나리오 없음(게이트 불필요).
tasks.md task 4(4.1) 체크. Build ✅ / Test ✅ 20.

## Completed Work (2026-06-02 — Profile 탭 Req 5)

"Coming soon" placeholder → 촬영 통계 화면. 1커밋.
- `ProfileStatsCalculator`(순수 enum) `compute(from:) -> ProfileStats(totalPhotos/topShotStyle/topFilterPreset)`. 빈도 최다, 동률 시 최근 createdAt 우선, nil 제외.
- `ProfileViewModel`(LoadState: loading/empty/loaded/failed) — `FetchPhotoPinsUseCase` 재사용해 PhotoItem 로드. 0건 empty(5.3)/실패 failed(5.6)/동기 2초내(5.7).
- `ProfileView`: 총촬영/최다 스타일(`ShotStyle.koreanDescription`+`symbolName`)/최다 프리셋 stat 카드 + 빈 상태 + 에러 재시도. LensNoteTheme 토큰만(5.5), placeholder 제거(5.4).
- `DIContainer.makeProfileViewModel()`, RootView `@StateObject profileVM`.
- property 테스트 4건(9.2 Property 8): 랜덤 100회 불변식 + tie-break/nil/빈배열.
tasks.md task 9(9.1/9.2) 체크. Build ✅ / Test ✅ 24.

## Completed Work (2026-06-02 — 지도 기간/지역 필터 Req 6)

지도 기간 필터 + 지역(영역) 목록. 2커밋.
- `DateRangeFilter`(all/today/thisWeek/thisMonth) `includes(_:now:calendar:)`: **롤링 윈도우**(today=최근 24h, thisWeek=최근 7일, thisMonth=최근 30일, all=무제한). ⚠️ **스펙(requirements.md 6.1)의 캘린더 경계(직전 월요일/1일)에서 변경됨** — 월 초에 "이번 주 > 이번 달" 역전이 생겨 사용자 요청으로 롤링으로 조정(커밋 717b6b4). today⊆week⊆month 항상 중첩. 칩 라벨은 오늘/이번 주/이번 달 유지.
- `MapViewModel`: `activeDateFilter`(.all 기본) + `filteredPins` + `applyDateFilter`(선택 핀이 새 필터 미포함이면 closeCard, Req 6.6).
- `DateFilterChipRow`(상단 칩, 활성 accentCyan / 비활성 surfaceHigh·textTertiary, 식별자 `map.filter.<case>`). `MapView.visiblePins`를 `filteredPins` 기반으로 전환 → 클러스터+목록 모두 기간 반영. 0건 시 "이 기간에 촬영된 사진이 없어요"(6.5). 지역 필터는 기존 `visiblePins`(현재 영역 내, 6.7).
- 공간 판정 `isCoordinate`를 `MapRegionFilter.contains(_:in:)` 순수 함수로 추출.
- property 테스트 6건(8.2 Property 3 / 8.3 Property 4 / 8.5 Property 5).
tasks.md task 8(8.1~8.5) 체크. Build ✅ / Test ✅ 30.

## Completed Work (2026-06-02 — CoreML/레퍼런스 안전성 Req 10)

이미 충족된 항목 확인(estimateCameraAngle midY fallback 10.2 — 0.35/0.65, thermalState serious×2.8/critical skip 10.6, 두 모델 실패 nil 10.4) + 미비점 보강(1커밋):
- `DeepLabV3Service`: semanticPredictions shape `[513,513]` 검증 → 불일치 시 `os.Logger` 에러 + nil(Req 10.3). gridSize 상수화.
- `CameraView`: 레퍼런스 분석을 `referenceAnalysisTask`로 보관 + 각 단계 `Task.isCancelled` 가드. `resetReferenceFlow`(뒤로가기)에서 cancel + 상태 초기화(Req 10.5).
tasks.md task 12(12.1) 체크. Build ✅ / Test ✅ 31.
⚠️ 실기기 CoreML 로드(10.1)·VNFaceLandmarks pitch(10.2)는 실기기 QA 잔여.

## Completed Work (2026-06-02 — 달성도 지표 Req 11)

3대 목표 기능 13개 항목에 os_log 달성/미달성 체크포인트(1커밋).
- `Application/AchievementLogger`(pass/fail/passOnce, category=Achievement). 수동 테스트로 앱 한 바퀴 → 콘솔에서 기능별 달성도(1:N/4, 2:N/4, 3:N/5) 집계.
- 1a~1d(레퍼런스 카메라: UIImage/ShotRecipe/forConcept/프리뷰), 2a~2d(코칭: 추론/Hint/배너/Delta), 3a~3e(지도: 재조회/핀/클러스터/카드/필터). 고빈도 경로는 passOnce.
tasks.md task 13(13.1) 체크. Build ✅ / Test ✅ 31.

## Kiro 평가 개선 스펙 — 완료 (2026-06-02)

**`.kiro/specs/lensnote-evaluation-improvement` 14개 태스크 + 선택 테스트 전부 완료.**
- Req 1(라이브 코칭)·2(결과 카드)·3(사이드 버튼)·4(a11y)·5(Profile 통계)·6(지도 필터, 롤링 윈도우로 조정)·7(MapView 분리)·8(영속성 스키마)·9(테스트 타겟)·10(CoreML/레퍼런스 안전성)·11(달성도 지표)·12(진입 간소화).
- 체크포인트 task 2/6/10/14 ✅. 자동화 테스트 31개 통과(8 suite).
- 실기기 기능 동작 확인 완료(사용자, 2026-06-02). 잔여 실기기 항목: Req 10.1 CoreML 로드/10.2 pitch 정밀 검증, 달성도 로그(콘솔 category=Achievement) 집계는 필요 시.

## Next Recommended Tasks

> Kiro 스펙은 완료. 다음 방향은 사용자 결정 대기. 후보:

1. **데모 준비** — 안정적 스크린샷/데모 경로 수집, Home 메시징 다듬기(BACKLOG Milestone 3).
2. **전체 회귀 패스** — 핵심 플로우 재점검.
3. **신규 백로그 항목** — 필터 추천 로직 고도화 등(BACKLOG Milestone 2).
4. **실기기 정밀 검증** — Req 10.1/10.2(CoreML·pitch), 발열 시 추론 간격 적응.

> ⚠️ **라이브 코칭 실기기 검증 잔여 (Req 1)**: 라이브 경로엔 face landmark가 없어 `cameraAngle`은 항상 nil → 현재 coverage 코칭("더 멀리/더 가까이")만 실제 동작. 앵글 코칭은 live ShotRecipe에 앵글이 추정되어야 동작(Req 10 pitch 연동 필요). 코칭 배너 체감/임계값(0.15)은 실기기에서 튜닝 필요.

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
- **홈 화면 디자인 개선: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4) — 실기기 확인은 다음 세션
- **컨셉 프리셋 실시간 미리보기: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4) — 실기기 확인 다음 세션
- **MapViewModel 서비스 분리: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4)
- **ShotRecipe 풀 분석: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4.1) — 사용자가 직접 시뮬레이터/실기기에서 4가지 스타일(항공샷·거울샷·발끝샷·뒷모습) 검증 예정
- **CameraReferenceStepView UX 결함 3건: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4.1) — 실기기 Dynamic Island 시각 검증은 다음 세션
- **ShotStyle 확장 (classicSelfie/landscape/closeUp) + 룰셋 갱신: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4.1) — classicSelfie/landscape 실기기 정확도 검증은 다음 세션
- **FloatingDockBar sub-step 가시성 제어: build-verified** (`BUILD SUCCEEDED`, iPhone 17 Pro Simulator, iOS 26.4.1) — 실기기 tap-through 확인은 다음 세션
- **wideSelfie + cameraAngle fallback: build-verified** (`BUILD SUCCEEDED`) — 실기기 정면/광각 셀피 → wideSelfie 라벨링 확인됨 (사용자 보고)
- **룰셋 미세 튜닝 + 한국어 조사: build-verified** (`BUILD SUCCEEDED`) — 39장 swift CLI 일괄 검증으로 unknown 8장 모두 의미 있는 라벨로 분류 확인. 실기기 재검증은 다음 세션
- **영속성 스키마 버전 + 마이그레이션 (Req 8): build-verified + 단위 테스트 검증** — 라운드트립/구버전 마이그레이션 테스트 통과. 실기기 force-quit→relaunch 런타임 검증은 미완료(Req 8 통합 테스트)
- **단위 테스트 타겟 (Req 9): test-verified** — `xcodebuild test` 13 tests passed (iPhone 17 Pro Simulator). swift-testing, 공유 스킴 TestAction 동작 확인
- Branch state: main only
- Last handoff: 2026-06-01

## Update Rule

At the end of each substantial work session, overwrite this file with the newest:

- completed work
- current blockers
- next exact task
- verification status
