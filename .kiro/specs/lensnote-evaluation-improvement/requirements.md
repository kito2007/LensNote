# Requirements Document

## Introduction

LensNote iOS 앱의 현재 구현 상태를 기준으로, 목표 기능 3가지(레퍼런스 기반 카메라 어시스턴트 / 실시간 구도 코칭 / 갤러리형 지도)의 달성도를 평가하고, 미완성 항목을 완성하며, UI/UX 품질과 기술적 안정성을 개선한다.

이 스펙은 세 가지 축으로 구성된다.

1. **기능 완성도 보완** — 라이브 코칭 델타 비교, 캡처 결과 피드백, 카메라 사이드 버튼 연결
2. **UI/UX 개선** — Profile 탭 완성, 접근성 식별자 추가, 지도 필터 UI
3. **기술적 보완** — MapView 파일 분리, 런타임 영속성 검증, 자동화 테스트 기반 구축

---

## Glossary

- **LensNote_App**: LensNote iOS 애플리케이션 전체
- **CameraViewModel**: 카메라 기능의 MVVM 뷰모델 (`CameraViewModel.swift`)
- **RealTimeInferenceEngine**: CoreML 듀얼 추론(MobileNetV2 + DeepLabV3)을 실행하는 엔진
- **ShotRecipeAnalyzer**: 레퍼런스 사진에서 ShotRecipe를 역추출하는 분석기
- **ShotRecipe**: 촬영 스타일(구도/각도/피사체 비율/EXIF)을 담은 도메인 엔티티
- **FilterPreset**: 노출/대비/채도/온도/비네트 값을 담은 필터 설정 엔티티
- **ActiveGuidanceHint**: 라이브 뷰에서 사용자에게 표시되는 실시간 구도 안내 문자열
- **LiveCoachingDelta**: 레퍼런스 ShotRecipe와 현재 프레임 ShotRecipe를 비교해 생성된 코칭 메시지
- **MapViewModel**: 지도 탭의 MVVM 뷰모델 (`MapViewModel.swift`)
- **PhotoPin**: 지도 위에 표시되는 사진 핀 도메인 엔티티
- **FilePhotoRepository**: JSON 파일 기반 사진 영속화 저장소
- **FetchPhotoPinsUseCase**: LensNote 자체 핀과 PHPhotoLibrary 핀을 머지해 반환하는 유스케이스
- **FloatingDockBar**: 커스텀 탭 내비게이션 오버레이
- **CameraLiveStepView**: 라이브 카메라 뷰 화면
- **CameraCaptureResultStepView**: 촬영 결과 확인 화면
- **MapView**: 지도 갤러리 화면 (`MapView.swift`)
- **ProfileView**: 프로필 탭 화면
- **AccessibilityIdentifier**: UI 자동화 테스트를 위한 안정적인 뷰 식별자
- **DIContainer**: 의존성 주입 컨테이너 (`DIContainer.swift`)
- **DateRangeFilter**: 지도 기간 필터 열거형 (오늘/이번 주/이번 달/전체)

---

## Requirements

---

### Requirement 1: 라이브 코칭 델타 비교 구현

**User Story:** As a 사진 촬영자, I want 레퍼런스 사진의 구도와 현재 카메라 프레임을 실시간으로 비교한 코칭 메시지를 받고 싶다, so that 레퍼런스와 유사한 구도로 촬영할 수 있다.

#### Acceptance Criteria

1. WHILE 레퍼런스 ShotRecipe가 설정된 상태이고, WHEN 라이브 뷰가 활성화되면, THE CameraViewModel SHALL 현재 프레임에서 ShotRecipe를 추출하여 레퍼런스 ShotRecipe와 비교한다.
2. WHEN 레퍼런스 ShotRecipe의 subjectCoverage와 현재 프레임의 subjectCoverage 차이가 +0.15 이상이면 THE CameraViewModel SHALL "더 멀리" 코칭 메시지를, -0.15 이하이면 "더 가까이" 코칭 메시지를 LiveCoachingDelta로 생성한다.
3. WHEN 레퍼런스 ShotRecipe의 cameraAngle과 현재 프레임의 cameraAngle이 다르면, THE CameraViewModel SHALL 다음 매핑에 따라 코칭 메시지를 생성한다: highAngle→eyeLevel="카메라를 내려주세요", lowAngle→eyeLevel="카메라를 올려주세요", eyeLevel→highAngle="카메라를 위로 올려주세요", eyeLevel→lowAngle="카메라를 아래로 내려주세요".
4. WHEN LiveCoachingDelta가 생성되면, THE CameraLiveStepView SHALL 기존 ActiveGuidanceHint 배너와 동일한 글래스 캡슐 UI로 코칭 메시지를 표시한다.
5. IF 레퍼런스 ShotRecipe가 설정되지 않은 상태이면, THEN THE CameraViewModel SHALL LiveCoachingDelta를 생성하지 않고 기존 Vision 기반 ActiveGuidanceHint만 표시한다.
6. WHEN 동일한 LiveCoachingDelta 메시지가 0.9초 미만으로 지속되면, THE CameraViewModel SHALL 해당 메시지를 ActiveGuidanceHint로 승격하지 않는다.
7. WHEN ActiveGuidanceHint가 노출된 후 1.6초가 경과하지 않으면, THE CameraViewModel SHALL 해당 힌트를 제거하지 않는다.
8. IF 현재 프레임의 subjectCoverage 또는 cameraAngle이 nil이면, THEN THE CameraViewModel SHALL 해당 축의 LiveCoachingDelta를 생성하지 않는다.

---

### Requirement 2: 캡처 결과 피드백 강화

**User Story:** As a 사진 촬영자, I want 촬영 후 저장 완료 여부와 지도 연결 상태를 명확히 확인하고 싶다, so that 내 사진이 LensNote 플로우에 정상적으로 저장되었다는 확신을 가질 수 있다.

#### Acceptance Criteria

1. WHEN 사진 저장이 완료되면, THE CameraCaptureResultStepView SHALL 저장된 사진의 썸네일, 촬영 위치명(역지오코딩 결과, 최대 3초 대기 후 타임아웃 시 "위치 확인 중…" 표시), 적용된 FilterPreset 이름을 포함한 결과 카드를 저장 완료 후 1초 이내에 표시한다.
2. WHEN 촬영 위치 좌표가 존재하면, THE CameraCaptureResultStepView SHALL "지도에서 보기" 버튼을 활성화하여 탭 시 MapView로 이동하고 해당 PhotoPin을 선택 상태로 표시한다.
3. WHEN 촬영 위치 좌표가 nil이면, THE CameraCaptureResultStepView SHALL "위치 정보 없음" 안내 텍스트를 표시하고 "지도에서 보기" 버튼을 비활성화(탭 불가) 상태로 표시한다.
4. WHEN 사진 저장이 실패하면, THE CameraCaptureResultStepView SHALL 실패 원인을 나타내는 에러 메시지와 재시도 버튼을 표시하며, 캡처된 이미지 데이터를 메모리에 유지하여 재시도 시 재촬영 없이 저장을 시도할 수 있도록 한다.
5. IF 레퍼런스 ShotRecipe가 설정된 상태에서 결과 카드가 표시되면, THEN THE CameraCaptureResultStepView SHALL 적용된 ShotStyle 라벨을 결과 카드 내에 함께 표시한다.
6. IF 역지오코딩 요청이 3초 이내에 응답하지 않으면, THEN THE CameraCaptureResultStepView SHALL 위치명 대신 "위치명을 불러올 수 없음" 텍스트를 표시하고 결과 카드의 나머지 정보는 정상 표시한다.

---

### Requirement 3: 카메라 사이드 버튼 액션 연결

**User Story:** As a 사진 촬영자, I want 라이브 뷰 화면의 사이드 버튼(지도/갤러리)을 탭하여 해당 화면으로 이동하고 싶다, so that 촬영 중에도 지도와 갤러리에 빠르게 접근할 수 있다.

#### Acceptance Criteria

1. WHEN 라이브 뷰 화면에서 지도 사이드 버튼을 탭하면, THE CameraLiveStepView SHALL 지도 탭으로 전환하는 콜백을 호출한다.
2. WHEN 라이브 뷰 화면에서 갤러리 사이드 버튼을 탭하면, THE CameraLiveStepView SHALL 시스템 사진 라이브러리 피커(PHPickerViewController)를 표시한다.
3. WHEN 시스템 사진 라이브러리 피커에서 사진을 선택하면, THE CameraLiveStepView SHALL 선택된 사진을 레퍼런스 이미지로 설정하고 레퍼런스 분석 단계로 전환한다.
4. WHEN 시스템 사진 라이브러리 피커에서 사진을 선택하지 않고 취소하면, THE CameraLiveStepView SHALL 피커를 닫고 라이브 뷰 상태를 유지한다.
5. IF 사진 라이브러리 접근 권한이 거부된 상태에서 갤러리 사이드 버튼을 탭하면, THEN THE CameraLiveStepView SHALL 권한 필요를 안내하는 에러 메시지를 표시하고 시스템 설정으로 이동할 수 있는 동선을 제공한다.
6. THE CameraLiveStepView SHALL 지도 사이드 버튼에 `"camera.side_map"` AccessibilityIdentifier를, 갤러리 사이드 버튼에 `"camera.side_gallery"` AccessibilityIdentifier를 부여한다.

---

### Requirement 4: 접근성 식별자 추가

**User Story:** As a QA 엔지니어, I want 핵심 UI 컨트롤에 안정적인 AccessibilityIdentifier가 부여되기를 원한다, so that XcodeBuildMCP 기반 시뮬레이터 자동화 테스트를 신뢰성 있게 실행할 수 있다.

#### Acceptance Criteria

1. THE CameraLiveStepView SHALL 셔터 버튼에 `"camera.shutter"` AccessibilityIdentifier를 부여하며, 버튼이 비활성 상태(촬영 진행 중)일 때에도 해당 식별자를 유지한다.
2. THE CameraLiveStepView SHALL AI 매직 버튼에 `"camera.ai_magic"` AccessibilityIdentifier를 부여한다.
3. THE CameraLiveStepView SHALL 구도 안내 배너에 `"camera.guidance_banner"` AccessibilityIdentifier를 부여한다. 배너는 activeGuidanceHint 값이 존재하여 화면에 렌더링된 경우에만 뷰 계층에 존재한다.
4. THE CameraSelectionStepView SHALL 레퍼런스 사진 분석 모드 버튼에 `"camera.select_reference"` AccessibilityIdentifier를 부여한다.
5. THE CameraSelectionStepView SHALL 텍스트 컨셉 입력 모드 버튼에 `"camera.select_concept"` AccessibilityIdentifier를 부여한다.
6. THE MapView SHALL 지도 핀 각각에 `"map.pin.\(photoPin.id)"` 형식의 AccessibilityIdentifier를 부여한다. 여기서 `photoPin.id`는 PhotoPin 모델의 UUID 문자열이다.
7. THE FloatingDockBar SHALL 각 탭 버튼에 `"dock.tab.home"`, `"dock.tab.camera"`, `"dock.tab.map"`, `"dock.tab.profile"` AccessibilityIdentifier를 부여한다.
8. WHILE 해당 뷰가 화면에 렌더링된 상태에서, THE 각 컨트롤 SHALL 뷰 상태 변경(선택, 비활성, 애니메이션 전환)과 무관하게 지정된 AccessibilityIdentifier 값을 변경 없이 유지한다.

---

### Requirement 5: Profile 탭 완성

**User Story:** As a 앱 사용자, I want Profile 탭에서 내 촬영 통계와 자주 사용하는 스타일 정보를 확인하고 싶다, so that 앱이 완성된 제품처럼 느껴진다.

#### Acceptance Criteria

1. THE ProfileView SHALL 총 촬영 횟수(정수), 가장 많이 사용한 ShotStyle 라벨(동률 시 최근 촬영 기준), 가장 많이 사용한 FilterPreset 이름(동률 시 최근 촬영 기준)을 각각 별도 영역에 표시한다.
2. THE ProfileView SHALL FilePhotoRepository에서 저장된 PhotoItem 목록을 읽어 통계를 계산하며, 각 PhotoItem에 연관된 ShotStyle과 FilterPreset 이름을 기반으로 빈도를 집계한다.
3. IF 저장된 사진이 0건이면, THEN THE ProfileView SHALL 촬영 통계 영역 대신 "아직 촬영한 사진이 없어요" 텍스트와 빈 상태 일러스트를 표시한다.
4. THE ProfileView SHALL placeholder 텍스트나 "Coming Soon" 문구를 포함하지 않는다.
5. THE ProfileView SHALL LensNoteTheme.Colors, LensNoteTheme.Typography, LensNoteTheme.Spacing 토큰만을 사용하여 색상, 서체, 간격을 지정한다.
6. IF FilePhotoRepository에서 데이터 읽기가 실패하면, THEN THE ProfileView SHALL 통계 영역에 데이터를 불러올 수 없음을 나타내는 에러 메시지를 표시한다.
7. WHEN ProfileView가 화면에 나타나면, THE ProfileView SHALL 2초 이내에 통계 데이터를 로드하여 표시한다.

---

### Requirement 6: 지도 기간/지역 필터

**User Story:** As a 사진 촬영자, I want 지도에서 특정 기간이나 지역으로 사진을 필터링하고 싶다, so that 많은 핀 중에서 원하는 사진을 빠르게 찾을 수 있다.

#### Acceptance Criteria

1. THE MapViewModel SHALL 기간 필터(오늘 / 이번 주 / 이번 달 / 전체)를 지원하는 `DateRangeFilter` 열거형을 정의하며, **롤링 윈도우 방식**으로 "오늘"은 현재 시각 기준 최근 24시간, "이번 주"는 최근 7일, "이번 달"은 최근 30일, "전체"는 모든 기간을 의미한다. (구현 변경 이력: 초기 정의는 캘린더 경계(직전 월요일 00:00 / 당월 1일 00:00)였으나, 월 초에 "이번 주"가 "이번 달"보다 넓어지는 직관 위반이 발생하여 `오늘 ⊆ 이번 주 ⊆ 이번 달` 중첩이 항상 성립하는 롤링 윈도우로 변경함 — 2026-06-02, 사용자 요청.)
2. WHEN 기간 필터가 변경되면, THE MapViewModel SHALL PhotoPin의 `createdAt` 값을 기기 로컬 타임존 기준으로 비교하여 해당 기간에 촬영된 PhotoPin만 지도에 표시한다.
3. THE MapView SHALL 지도 상단에 기간 필터 선택 칩 행을 표시하며, 앱 진입 시 기본 선택 값은 "전체"로 설정한다.
4. WHEN 필터 칩을 탭하면, THE MapView SHALL 선택된 필터를 accentCyan 색상으로 강조하고 나머지 칩은 LensNoteTheme의 비활성 배경색과 텍스트색으로 표시한다.
5. WHEN 활성 필터 조건에 해당하는 핀이 없으면, THE MapView SHALL "이 기간에 촬영된 사진이 없어요" 빈 상태 메시지를 지도 중앙에 표시한다.
6. WHEN 기간 필터가 변경될 때 현재 선택된 핀이 새 필터 조건에 포함되지 않으면, THE MapViewModel SHALL 핀 선택을 해제하고 핀 카드를 닫는다.
7. WHEN 지도 영역이 변경되면, THE MapView SHALL 현재 지도 화면 영역 내에 위치한 PhotoPin만 목록 패널에 표시하여 지역 기반 탐색을 지원한다.

---

### Requirement 7: MapView 파일 분리

**User Story:** As a iOS 개발자, I want MapView.swift의 private struct들이 별도 파일로 분리되기를 원한다, so that 파일 크기가 관리 가능한 수준이 되고 코드 탐색이 용이해진다.

#### Acceptance Criteria

1. THE LensNote_App SHALL MapView.swift 내 private struct로 정의된 서브뷰(PinAnnotationView, ClusterBadgeView, SidePanelList, PinCardView, PermissionOverlayView, MapEmptyStateView, LoadingBannerView, ClusterItem)를 `Features/Map/Views/` 디렉토리의 별도 파일로 분리한다.
2. WHEN 파일 분리 후 빌드를 실행하면, THE LensNote_App SHALL `BUILD SUCCEEDED`를 반환한다.
3. THE LensNote_App SHALL 파일 분리 후 MapView.swift의 라인 수가 300줄 이하가 되도록 한다.
4. THE LensNote_App SHALL 분리된 각 파일이 LensNoteTheme 토큰을 직접 참조하여 독립적으로 렌더링 가능하도록 한다.
5. THE LensNote_App SHALL 분리된 각 struct의 접근 제어를 `internal`(기본값)로 변경하여 MapView.swift에서 참조 가능하도록 한다.

---

### Requirement 8: 런타임 영속성 검증

**User Story:** As a QA 엔지니어, I want 카메라로 촬영한 사진이 앱 재시작 후에도 지도에 표시되는지 검증하고 싶다, so that FilePhotoRepository의 영속성이 실제로 동작함을 확인할 수 있다.

#### Acceptance Criteria

1. WHEN 카메라로 사진을 촬영하고 저장한 후 앱을 강제 종료(사용자가 앱 스위처에서 제거 또는 시스템에 의한 프로세스 종료)하면, THE FilePhotoRepository SHALL 저장된 PhotoItem을 Documents 디렉토리의 JSON 파일에 유지하며, 해당 PhotoItem의 imagePath가 참조하는 이미지 파일도 Documents 디렉토리에 존재해야 한다.
2. WHEN 앱을 재시작하면, THE FetchPhotoPinsUseCase SHALL 이전 세션에서 저장된 모든 PhotoItem을 반환하고, MapViewModel은 반환된 PhotoItem을 지도 핀으로 표시한다.
3. IF PhotoItem JSON 디코딩이 실패하면, THEN THE FilePhotoRepository SHALL 빈 배열을 반환하고 에러 내용을 os_log 또는 print를 통해 콘솔에 기록한다.
4. THE FilePhotoRepository SHALL PhotoItem 배열을 저장할 때 정수형 `schemaVersion` 필드(초기값 1)를 JSON 최상위 레벨에 포함한다.
5. IF 저장된 JSON의 `schemaVersion`이 현재 앱이 지원하는 schemaVersion보다 낮으면, THEN THE FilePhotoRepository SHALL 해당 버전에서 현재 버전으로의 마이그레이션을 수행한 후 PhotoItem 배열을 반환한다.
6. IF 저장된 JSON의 `schemaVersion`이 현재 앱이 지원하는 schemaVersion보다 높거나 마이그레이션이 실패하면, THEN THE FilePhotoRepository SHALL 빈 배열을 반환하고 에러 내용을 콘솔에 기록한다.

---

### Requirement 9: 자동화 테스트 기반 구축

**User Story:** As a iOS 개발자, I want 핵심 도메인 로직에 대한 자동화 테스트가 존재하기를 원한다, so that 코드 변경 시 회귀 버그를 조기에 발견할 수 있다.

#### Acceptance Criteria

1. THE LensNote_App SHALL `AIInferenceAggregator.aggregate`의 inferenceScore 계산 로직에 대해 최소 3개의 단위 테스트를 포함하며, 각 테스트는 (a) confidence=0, compositionScore=0 입력 시 결과가 0.0인 경우, (b) confidence=1.0, compositionScore=1.0 입력 시 결과가 1.0인 경우, (c) scene=nil, segmentation=nil 입력 시 크래시 없이 기본값을 반환하는 경우를 검증한다.
2. THE LensNote_App SHALL `ShotRecipeAnalyzer`의 ShotStyle 라벨링 룰에 대해 최소 4개의 단위 테스트를 포함하며, 각 테스트는 서로 다른 ShotStyle(aerialSelfie, mirrorSelfie, landscape, unknown 중 최소 4종)에 대해 해당 분류 조건의 입력이 주어졌을 때 올바른 ShotStyle 열거값을 반환하는지 검증한다.
3. THE LensNote_App SHALL `FilterPreset.forConcept(_:)` 키워드 매핑 로직에 대해 최소 3개의 단위 테스트를 포함하며, 각 테스트는 (a) 매핑된 키워드 입력 시 해당 프리셋 name을 반환하는 경우, (b) 빈 문자열 입력 시 "Standard" 프리셋을 반환하는 경우, (c) 매핑되지 않은 키워드 입력 시 "Standard" 프리셋을 반환하는 경우를 검증한다.
4. THE LensNote_App SHALL `FilePhotoRepository`의 저장/읽기 라운드트립에 대해 최소 2개의 단위 테스트를 포함하며, 각 테스트는 (a) 유효한 PhotoItem을 save한 후 fetchAll 호출 시 동일한 객체가 포함된 배열을 반환하는 경우, (b) 파일이 존재하지 않는 초기 상태에서 fetchAll 호출 시 빈 배열을 반환하는 경우를 검증한다.
5. FOR ALL 유효한 PhotoItem 객체, THE FilePhotoRepository SHALL 저장 후 읽기 시 모든 프로퍼티(id, createdAt, imagePath, coordinate)가 동일한 객체를 반환한다.
6. FOR ALL 유효한 FilterPreset 객체, THE LensNote_App SHALL JSON 직렬화 후 역직렬화 시 모든 프로퍼티(name, exposure, contrast, saturation, temperature, vignette)가 동일한 객체를 반환한다.
7. IF 단위 테스트 대상 메서드의 입력이 nil 또는 빈 값인 경우, THEN THE LensNote_App SHALL 크래시 없이 기본값 또는 빈 결과를 반환함을 검증하는 테스트를 각 대상 모듈당 최소 1개 포함한다.

---

### Requirement 10: 실기기 CoreML 추론 검증

**User Story:** As a iOS 개발자, I want CoreML 듀얼 추론이 실기기에서 정상 동작함을 확인하고 싶다, so that 시뮬레이터 검증만으로는 확인할 수 없는 실기기 특이 동작을 사전에 파악할 수 있다.

#### Acceptance Criteria

1. WHEN 실기기에서 라이브 뷰를 활성화하면, THE RealTimeInferenceEngine SHALL MobileNetV2와 DeepLabV3 모델을 각각 5초 이내에 로드하고, 첫 번째 프레임 도달 후 baseInterval(0.5초) 경과 시점에 추론 결과(SceneClassificationResult 또는 SegmentationResult)를 1건 이상 반환한다.
2. WHEN 실기기에서 VNDetectFaceLandmarksRequest를 실행하면, THE ShotRecipeAnalyzer SHALL yaw/pitch 값을 각각 -1.0~1.0 범위의 Double로 수신하거나, nil인 경우 피사체 바운딩 박스의 midY 값(0.0~1.0)을 기준으로 cameraAngle fallback(midY < 0.35 → highAngle, midY > 0.65 → lowAngle, 그 외 → eyeLevel)을 적용한다.
3. IF DeepLabV3 MLMultiArray의 shape이 [513, 513]이 아닌 경우, THEN THE DeepLabV3Service SHALL 에러를 로그에 기록하고 nil을 반환하며, RealTimeInferenceEngine은 크래시 없이 다음 프레임 추론을 계속한다.
4. IF CoreML 모델 파일(MobileNetV2.mlmodelc 또는 DeepLabV3.mlmodelc)이 번들에 없으면, THEN THE RealTimeInferenceEngine SHALL 해당 모델의 추론을 건너뛰고 나머지 모델의 결과만으로 AIInferenceOutput을 생성하며, 두 모델 모두 없는 경우 nil을 반환하되 크래시나 uncaught exception 없이 동작을 지속한다.
5. WHEN 레퍼런스 분석 중 사용자가 뒤로가기를 탭하면, THE CameraView SHALL 진행 중인 ShotRecipeAnalyzer Task를 취소하고 referenceAnalysisStage를 idle로, referenceGeneratedPreset과 referenceGeneratedRecipe를 nil로 초기화하여 선택 화면(step = .select)으로 복귀한다.
6. WHILE 실기기의 thermalState가 serious 이상이면, THE RealTimeInferenceEngine SHALL 추론 간격을 baseInterval 대비 2.8배 이상으로 증가시키고, critical 상태에서는 추론을 완전히 건너뛰어 nil을 반환한다.

---

### Requirement 11: 목표 기능 달성도 평가 지표

**User Story:** As a 제품 개발자, I want 목표 기능 3가지의 달성도를 정량적으로 평가할 수 있는 기준이 존재하기를 원한다, so that 현재 구현 상태와 목표 간의 갭을 명확히 파악할 수 있다.

#### Acceptance Criteria

1. THE LensNote_App SHALL 목표 기능 1(레퍼런스 기반 카메라)에 대해 다음 4개 항목 각각이 에러 없이 완료되고 후속 단계에 유효한 출력을 전달할 때 해당 항목을 "달성"으로 간주한다: (a) 레퍼런스 사진 선택 시 UIImage가 nil이 아닌 상태로 반환됨, (b) ShotRecipeAnalyzer가 ShotRecipe 객체를 nil 없이 생성함, (c) FilterPreset.forConcept이 유효한 FilterPreset 객체를 반환함, (d) 라이브 뷰에 FilterPreset이 적용된 상태로 카메라 프리뷰가 렌더링됨.
2. THE LensNote_App SHALL 목표 기능 2(실시간 구도 코칭)에 대해 다음 4개 항목 각각이 에러 없이 완료되고 후속 단계에 유효한 출력을 전달할 때 해당 항목을 "달성"으로 간주한다: (a) RealTimeInferenceEngine이 라이브 프레임에서 CoreML 추론 결과를 반환함, (b) 추론 결과로부터 ActiveGuidanceHint 문자열이 생성됨, (c) CameraLiveStepView에 구도 안내 배너가 노출됨, (d) 레퍼런스 ShotRecipe 설정 시 LiveCoachingDelta 비교 코칭 메시지가 생성되어 배너에 표시됨.
3. THE LensNote_App SHALL 목표 기능 3(갤러리형 지도)에 대해 다음 5개 항목 각각이 에러 없이 완료되고 후속 단계에 유효한 출력을 전달할 때 해당 항목을 "달성"으로 간주한다: (a) 촬영 사진이 FilePhotoRepository에 저장되고 재조회 시 동일 데이터가 반환됨, (b) 저장된 PhotoPin이 MapView 지도 위에 핀으로 표시됨, (c) 반경 내 2개 이상의 핀이 클러스터로 그룹화됨, (d) 핀 탭 시 사진 썸네일과 촬영 정보를 포함한 상세 카드가 표시됨, (e) 기간 필터 칩 선택 시 해당 기간의 핀만 지도에 표시됨.
4. WHEN 목표 기능 달성도 평가를 수동 테스트로 실행하면, THE LensNote_App SHALL 각 기능별 달성 항목 수와 전체 항목 수를 비율로 산출하여(기능 1: N/4, 기능 2: N/4, 기능 3: N/5) 달성 항목과 미달성 항목을 구분하여 테스트 리포트에 기록할 수 있도록 한다.
5. IF 목표 기능의 특정 항목이 에러를 반환하거나 후속 단계에 유효한 출력을 전달하지 못하면, THEN THE LensNote_App SHALL 해당 항목을 "미달성"으로 분류하고, 실패 원인(에러 메시지 또는 nil 반환)을 식별 가능하도록 로그에 기록한다.


---

### Requirement 12: 카메라 진입 플로우 간소화

**User Story:** As a 사진 촬영자, I want 카메라 탭을 누르면 바로 촬영할 수 있기를 원한다, so that 불필요한 모드 선택 단계 없이 빠르게 촬영을 시작할 수 있다.

#### Acceptance Criteria

1. WHEN 사용자가 카메라 탭을 탭하면, THE CameraView SHALL 모드 선택 화면(CameraSelectionStepView)을 거치지 않고 즉시 라이브 카메라 뷰(step = .camera)를 표시한다.
2. THE CameraLiveStepView SHALL 라이브 뷰 화면 내에서 레퍼런스 사진 선택과 컨셉 입력 기능에 접근할 수 있는 최소한의 진입점(사이드 버튼 또는 하단 컨트롤)을 제공한다.
3. THE CameraView SHALL 기존 CameraSelectionStepView(4가지 모드 선택 화면)를 제거하고, 해당 화면에서 제공하던 기능(레퍼런스 분석, 텍스트 컨셉, 수동 설정)을 라이브 뷰 내 인라인 UI 또는 바텀 시트로 통합한다.
4. WHEN 라이브 뷰에서 레퍼런스 사진 버튼을 탭하면, THE CameraView SHALL 사진 라이브러리 피커를 즉시 표시하고, 사진 선택 후 레퍼런스 분석 결과를 라이브 뷰 위에 오버레이로 표시한다.
5. WHEN 라이브 뷰에서 컨셉 입력 버튼을 탭하면, THE CameraView SHALL 하단 시트 또는 인라인 입력 필드를 표시하여 키워드 입력 후 즉시 프리셋을 적용한다.
6. THE CameraView SHALL 수동 설정(노출/대비/채도/온도/비네트 슬라이더)을 라이브 뷰 내 접이식 패널 또는 스와이프 제스처로 접근 가능하도록 통합한다.
7. THE CameraView SHALL 카메라 진입부터 첫 번째 셔터 탭까지 필요한 최소 탭 수를 2회 이하(탭 바 탭 1회 + 셔터 탭 1회)로 유지한다.
8. IF 사용자가 이전에 레퍼런스 사진을 설정한 상태에서 카메라 탭을 재진입하면, THEN THE CameraView SHALL 이전 레퍼런스 설정을 유지한 상태로 라이브 뷰를 표시한다.
