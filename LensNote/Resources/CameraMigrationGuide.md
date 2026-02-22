# Camera UI Migration Guide

## Scope
- Figma export의 `CameraView.tsx` 플로우를 SwiftUI로 우선 이식한다.
- 단계형 UX를 먼저 고정하고, CoreML/Vision 기능은 인터페이스 분리 후 순차 탑재한다.

## Current Mapping
- `select`: 입력 방식 선택
- `photo`: 레퍼런스 업로드 + 분석 대기
- `text`: 컨셉 입력
- `manual`: 수동 필터 설정
- `camera`: 라이브 카메라 + 추천 패널 + 구도 가이드
- `result`: 캡처 결과 + 저장/재촬영

## Token Baseline (Temporary)
- spacing: `4, 8, 12, 16, 20, 24, 32`
- radius: `10, 14, 22, 28`
- typography:
  - large title `34/bold`
  - section title `22/semibold`
  - body `17/regular`
  - headline `17/semibold`
  - footnote `13/regular`
- motion:
  - step transition `easeInOut 0.25s`
  - panel reveal `spring(0.35, 0.86)`
  - success toast `1.8s`

## Architecture Rule
- UI 상태와 추론/추천 로직을 분리한다.
- `CameraAssistServiceProtocol`을 통해 CoreML 결과를 UI에 주입한다.
- View는 추론을 직접 수행하지 않고 DTO만 렌더링한다.

## TODO (UI First)
1. Step별 화면 스냅샷 수집(`select/photo/text/manual/camera/result`)
2. `manual` 단계 슬라이더 프리셋 저장/복원 UX 추가
3. `result` 단계에 실제 캡처 썸네일 연결
4. Dynamic Type/VoiceOver 접근성 텍스트 점검
5. 작은 화면(iPhone SE) 레이아웃 오버플로우 확인
6. 큰 화면(iPhone Pro Max) 카드 폭/가독성 조정
7. 다크 환경 대비 컬러 콘트라스트 점검

## TODO (Feature Integration)
1. CoreML 추론 입력 스키마 정의(프레임/메타데이터)
2. `MockCameraAssistService` -> `CoreMLCameraAssistService` 교체
3. 추천값 캐싱 및 프레임 샘플링 간격 최적화
4. 실시간 분석 실패 시 fallback 문구/재시도 정책 추가
5. 저장 파이프라인에서 실제 이미지 경로 및 메타데이터 저장
