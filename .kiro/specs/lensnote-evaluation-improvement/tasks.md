# Implementation Plan: LensNote Evaluation Improvement

## Overview

이 구현 계획은 LensNote iOS 앱의 목표 기능 달성도를 높이기 위한 12개 요구사항을 코딩 태스크로 분해한다. 기존 MVVM + UseCase + Repository 아키텍처를 유지하면서, 카메라 플로우 간소화 → 라이브 코칭 → 캡처 피드백 → 지도 필터 → 기술적 안정성 순서로 점진적으로 구현한다.

## Tasks

- [x] 1. 카메라 진입 플로우 간소화 및 MapView 파일 분리
  - [x] 1.1 MapView.swift 서브뷰를 별도 파일로 분리
    - `Features/Map/Views/` 디렉토리에 PinAnnotationView.swift, ClusterBadgeView.swift, SidePanelList.swift, PinCardView.swift, PermissionOverlayView.swift, MapEmptyStateView.swift, LoadingBannerView.swift 생성
    - `Features/Map/Models/ClusterItem.swift` 생성
    - 각 struct의 접근 제어를 `private` → `internal`로 변경
    - MapView.swift에서 분리된 struct 참조 확인, 300줄 이하 달성
    - 각 파일이 LensNoteTheme 토큰을 직접 참조하여 독립 렌더링 가능하도록 import 정리
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 1.2 CameraView 플로우 간소화 — CameraSelectionStepView 제거 및 즉시 라이브 뷰 진입
    - `CameraInputMode` enum에서 `.select` 케이스 제거, 초기 step을 `.camera`로 변경
    - `CameraSelectionStepView.swift` 파일 제거 (또는 dead code 정리)
    - `InlineMode` enum 추가 (none/reference/concept/manual)
    - 라이브 뷰 내에서 레퍼런스/컨셉/수동 설정 진입점 UI 구현 (사이드 버튼 또는 하단 컨트롤)
    - 레퍼런스 버튼 탭 → PHPicker 즉시 표시, 분석 결과를 라이브 뷰 위 오버레이로 표시
    - 컨셉 버튼 탭 → 하단 시트 또는 인라인 입력 필드 표시
    - 수동 설정 → 접이식 패널 또는 스와이프 제스처로 접근
    - 카메라 진입부터 셔터까지 최소 탭 수 2회 이하 유지
    - 이전 레퍼런스 설정 유지 상태로 재진입 지원
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8_

  - [x] 1.3 접근성 식별자 추가
    - CameraLiveStepView: `"camera.shutter"`, `"camera.ai_magic"`, `"camera.guidance_banner"`, `"camera.side_map"`, `"camera.side_gallery"` 부여
    - CameraSelectionStepView 제거 후 해당 식별자(`"camera.select_reference"`, `"camera.select_concept"`)를 새 인라인 UI에 부여
    - MapView: 각 핀에 `"map.pin.\(photoPin.id)"` 형식 식별자 부여
    - FloatingDockBar: `"dock.tab.home"`, `"dock.tab.camera"`, `"dock.tab.map"`, `"dock.tab.profile"` 부여
    - 뷰 상태 변경(선택, 비활성, 애니메이션)과 무관하게 식별자 유지 확인
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_

- [ ] 2. Checkpoint — 빌드 확인
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. LiveCoachingEngine 구현
  - [x] 3.1 LiveCoachingDelta 모델 및 LiveCoachingEngine 순수 함수 구현
    - `Features/Camera/LiveCoachingEngine.swift` 생성
    - `LiveCoachingDelta` struct 정의 (coverageMessage, angleMessage, primaryMessage, isEmpty)
    - `LiveCoachingEngine.compare(reference:live:)` 구현
    - coverageThreshold = 0.15 적용: (live - ref) >= 0.15 → "더 멀리", <= -0.15 → "더 가까이"
    - cameraAngle 매핑: highAngle→eyeLevel="카메라를 내려주세요", lowAngle→eyeLevel="카메라를 올려주세요", eyeLevel→highAngle="카메라를 위로 올려주세요", eyeLevel→lowAngle="카메라를 아래로 내려주세요"
    - reference nil → nil 반환, coverage/angle nil → 해당 축 메시지 생략
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.8_

  - [x]* 3.2 Write property test for LiveCoachingEngine coverage delta
    - **Property 1: Coverage delta coaching message correctness**
    - **Validates: Requirements 1.2, 1.8**
    - 랜덤 Double(0...1) coverage 쌍으로 100회 반복 검증

  - [x]* 3.3 Write property test for no coaching without reference
    - **Property 2: No coaching delta without reference**
    - **Validates: Requirements 1.5**
    - 랜덤 ShotRecipe + nil reference로 100회 반복 검증

  - [x] 3.4 CameraViewModel에 라이브 코칭 통합
    - CameraViewModel에 `referenceShotRecipe: ShotRecipe?` 프로퍼티 추가
    - 라이브 프레임에서 ShotRecipe 추출 로직 추가 (기존 RealTimeInferenceEngine 결과 활용)
    - `LiveCoachingEngine.compare(reference:live:)` 호출하여 LiveCoachingDelta 생성
    - 디바운스 로직: 동일 메시지 0.9초 미만 지속 시 미승격, 노출 후 1.6초 미만 미제거
    - `activeGuidanceHint`에 LiveCoachingDelta.primaryMessage 반영
    - 레퍼런스 미설정 시 기존 Vision 기반 ActiveGuidanceHint만 표시
    - _Requirements: 1.1, 1.4, 1.5, 1.6, 1.7, 1.8_

  - [x] 3.5 CameraLiveStepView에 라이브 코칭 배너 UI 연결
    - 기존 guidanceBanner와 동일한 글래스 캡슐 UI로 LiveCoachingDelta 메시지 표시
    - `liveCoachingMessage` 프로퍼티 추가 및 CameraView에서 전달
    - _Requirements: 1.4_

- [x] 4. 카메라 사이드 버튼 액션 연결
  - [x] 4.1 사이드 버튼 콜백 구현
    - CameraLiveStepView에 `onMapTap`, `onGalleryTap` 콜백 추가
    - 지도 버튼 탭 → 지도 탭 전환 콜백 호출
    - 갤러리 버튼 탭 → PHPickerViewController 표시
    - 사진 선택 시 레퍼런스 이미지로 설정 + 레퍼런스 분석 단계 전환
    - 취소 시 피커 닫기 + 라이브 뷰 유지
    - 사진 라이브러리 권한 거부 시 에러 메시지 + 설정 이동 동선 제공
    - AccessibilityIdentifier: `"camera.side_map"`, `"camera.side_gallery"` 확인
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 5. 캡처 결과 피드백 강화
  - [x] 5.1 CameraCaptureResultStepView 결과 카드 구현
    - `CaptureResultInfo` 모델 정의 (thumbnail, placeName, filterPresetName, shotStyleLabel, coordinate, canNavigateToMap)
    - 저장 완료 후 1초 이내에 결과 카드 표시
    - 역지오코딩 결과 표시 (3초 타임아웃 → "위치명을 불러올 수 없음")
    - 적용된 FilterPreset 이름 표시
    - 레퍼런스 ShotRecipe 설정 시 ShotStyle 라벨 표시
    - "지도에서 보기" 버튼: 좌표 존재 시 활성 → MapView 이동 + PhotoPin 선택, 좌표 nil 시 비활성 + "위치 정보 없음" 안내
    - 저장 실패 시 에러 메시지 + 재시도 버튼, 이미지 데이터 메모리 유지
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ] 6. Checkpoint — 빌드 및 카메라 플로우 확인
  - Ensure all tests pass, ask the user if questions arise.

- [~] 7. FilePhotoRepository 스키마 버전 및 영속성 강화
  - [x] 7.1 PhotoStorageEnvelope 도입 및 마이그레이션 로직 구현 — Done 2026-06-01 (커밋 f1a6b08)
    - `PhotoStorageEnvelope` struct 정의 (schemaVersion: Int, items: [PhotoItem])
    - `currentVersion = 1` 상수 정의
    - 저장 시 schemaVersion 필드를 JSON 최상위에 포함
    - 읽기 시 schemaVersion 검사: < current → 마이그레이션 실행, > current → 빈 배열 + 에러 로그
    - JSON 디코딩 실패 시 빈 배열 반환 + os_log 에러 기록
    - PhotoItem에 `shotStyle: ShotStyle?`, `filterPresetName: String?` 필드 추가
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

  - [ ]* 7.2 Write property test for PhotoItem persistence round-trip
    - **Property 6: PhotoItem persistence round-trip**
    - **Validates: Requirements 8.1, 8.2, 9.5**
    - 랜덤 PhotoItem 생성 → save → fetchAll → 동일 프로퍼티 검증, 100회 반복

  - [ ]* 7.3 Write property test for FilterPreset serialization round-trip
    - **Property 7: FilterPreset serialization round-trip**
    - **Validates: Requirements 9.6**
    - 랜덤 FilterPreset 생성 → JSON encode → decode → 동일 프로퍼티 검증, 100회 반복

- [ ] 8. 지도 기간/지역 필터 구현
  - [ ] 8.1 DateRangeFilter 열거형 및 MapViewModel 필터 로직 구현
    - `Features/Map/DateRangeFilter.swift` 생성
    - `DateRangeFilter` enum 정의 (today/thisWeek/thisMonth/all) + `includes(_:now:calendar:)` 메서드
    - "오늘": 당일 00:00:00~현재, "이번 주": 직전 월요일 00:00:00~현재, "이번 달": 당월 1일 00:00:00~현재, "전체": 항상 true
    - MapViewModel에 `activeDateFilter: DateRangeFilter = .all` 추가
    - `filteredPins` computed property: activeDateFilter 기반 핀 필터링
    - `applyDateFilter(_:)`: 필터 변경 시 선택된 핀이 새 필터에 미포함이면 선택 해제
    - 기기 로컬 타임존 기준 비교
    - _Requirements: 6.1, 6.2, 6.6_

  - [ ]* 8.2 Write property test for DateRangeFilter date inclusion
    - **Property 3: DateRangeFilter date inclusion correctness**
    - **Validates: Requirements 6.1, 6.2**
    - 랜덤 Date + 랜덤 filter + 고정 now로 100회 반복 검증

  - [ ]* 8.3 Write property test for filter change clears invalid selection
    - **Property 4: Filter change clears invalid selection**
    - **Validates: Requirements 6.6**
    - 랜덤 pin + 랜덤 filter 전환으로 100회 반복 검증

  - [ ] 8.4 MapView 필터 칩 UI 및 지역 필터 구현
    - 지도 상단에 기간 필터 선택 칩 행 표시, 기본값 "전체"
    - 선택된 칩: accentCyan 강조, 나머지: LensNoteTheme 비활성 배경/텍스트
    - 필터 결과 0건 시 "이 기간에 촬영된 사진이 없어요" 빈 상태 메시지 표시
    - 지도 영역 변경 시 현재 화면 영역 내 PhotoPin만 목록 패널에 표시 (지역 기반 탐색)
    - _Requirements: 6.3, 6.4, 6.5, 6.7_

  - [ ]* 8.5 Write property test for spatial region filtering
    - **Property 5: Spatial region filtering**
    - **Validates: Requirements 6.7**
    - 랜덤 좌표 핀 + 랜덤 MKCoordinateRegion으로 100회 반복 검증

- [x] 9. Profile 탭 완성
  - [x] 9.1 ProfileStatsCalculator 및 ProfileView 구현
    - `Features/Profile/ProfileStatsCalculator.swift` 생성
    - `ProfileStats` struct 정의 (totalPhotos, topShotStyle, topFilterPreset)
    - `ProfileStatsCalculator.compute(from:)` 순수 함수 구현 (동률 시 최근 촬영 기준)
    - ProfileView에서 FilePhotoRepository 데이터 읽어 통계 표시
    - 총 촬영 횟수, 가장 많이 사용한 ShotStyle, 가장 많이 사용한 FilterPreset 각각 별도 영역
    - 0건 시 "아직 촬영한 사진이 없어요" + 빈 상태 일러스트
    - 데이터 읽기 실패 시 에러 메시지 표시
    - placeholder/"Coming Soon" 문구 제거
    - LensNoteTheme 토큰만 사용 (Colors, Typography, Spacing)
    - 2초 이내 데이터 로드
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

  - [x]* 9.2 Write property test for ProfileStatsCalculator
    - **Property 8: Profile statistics computation**
    - **Validates: Requirements 5.1**
    - 랜덤 PhotoItem 배열로 100회 반복 검증 (totalPhotos, topShotStyle, topFilterPreset)

- [ ] 10. Checkpoint — 빌드 및 전체 기능 확인
  - Ensure all tests pass, ask the user if questions arise.

- [~] 11. 자동화 테스트 기반 구축
  - [x] 11.1 단위 테스트 타겟 생성 및 핵심 도메인 테스트 작성 — Done 2026-06-01 (커밋 20a0675, 13 tests pass)
    - Xcode 테스트 타겟 생성 (LensNoteTests)
    - AIInferenceAggregator.aggregate 테스트 3개: (a) 0/0→0.0, (b) 1.0/1.0→1.0, (c) nil/nil→기본값
    - ShotRecipeAnalyzer ShotStyle 라벨링 테스트 4개: aerialSelfie, mirrorSelfie, landscape, unknown 각 조건
    - FilterPreset.forConcept 테스트 3개: (a) 매핑 키워드, (b) 빈 문자열→Standard, (c) 미매핑→Standard
    - FilePhotoRepository 테스트 2개: (a) save→fetchAll 라운드트립, (b) 빈 초기 상태→빈 배열
    - nil/빈 값 입력 시 크래시 없이 기본값 반환 테스트 (모듈당 1개 이상)
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_

  - [ ]* 11.2 Write unit tests for LiveCoachingEngine cameraAngle mapping
    - 6개 non-equal (ref, live) cameraAngle 쌍 → 올바른 메시지 검증
    - 디바운스 로직 테스트: 0.9s 미만 미승격, 1.6s 미만 미제거
    - _Requirements: 1.3, 1.6, 1.7_

- [ ] 12. 실기기 CoreML 추론 검증 및 안전성 강화
  - [ ] 12.1 RealTimeInferenceEngine 안전성 코드 보강
    - DeepLabV3 MLMultiArray shape [513, 513] 검증 → 불일치 시 에러 로그 + nil 반환
    - CoreML 모델 파일 번들 부재 시 해당 모델 추론 건너뛰기, 두 모델 모두 없으면 nil 반환 (크래시 없음)
    - thermalState serious → 추론 간격 baseInterval × 2.8 이상, critical → 추론 건너뜀 + nil 반환
    - 레퍼런스 분석 중 뒤로가기 시 ShotRecipeAnalyzer Task 취소 + 상태 초기화 (referenceAnalysisStage → .idle)
    - VNDetectFaceLandmarksRequest yaw/pitch nil 시 midY fallback 적용 확인
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

- [ ] 13. 목표 기능 달성도 평가 지표 구현
  - [ ] 13.1 달성도 평가 로그 및 검증 포인트 추가
    - 기능 1 (레퍼런스 카메라) 4개 항목 각각에 성공/실패 로그 포인트 추가
    - 기능 2 (실시간 코칭) 4개 항목 각각에 성공/실패 로그 포인트 추가
    - 기능 3 (갤러리형 지도) 5개 항목 각각에 성공/실패 로그 포인트 추가
    - 각 항목 에러 시 실패 원인(에러 메시지 또는 nil 반환)을 os_log로 기록
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [ ] 14. Final checkpoint — 전체 빌드 및 테스트 통과 확인
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- 프로젝트는 PBXFileSystemSynchronizedRootGroup을 사용하므로 새 파일 생성 시 Xcode 타겟 멤버십 수동 조작 불필요
- LensNoteTheme 디자인 시스템 토큰을 모든 UI 구현에서 사용할 것
- swift-testing 프레임워크를 프로퍼티 기반 테스트에 사용

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["3.1", "7.1", "8.1"] },
    { "id": 3, "tasks": ["3.2", "3.3", "7.2", "7.3", "8.2", "8.3"] },
    { "id": 4, "tasks": ["3.4", "3.5", "4.1", "8.4", "8.5"] },
    { "id": 5, "tasks": ["5.1", "9.1"] },
    { "id": 6, "tasks": ["9.2", "11.1", "11.2"] },
    { "id": 7, "tasks": ["12.1", "13.1"] }
  ]
}
```
