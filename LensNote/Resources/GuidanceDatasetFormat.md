# Guidance Dataset Format

카메라 어시스트 학습/평가용 샘플은 JSONL 형식으로 저장됩니다.

- 저장 경로: Documents/LensNoteAnalytics/composition_guidance_samples.jsonl
- 형식: 한 줄에 하나의 JSON 객체

## Record Schema

| Key | Type | Description |
| --- | --- | --- |
| `timestamp` | String | ISO8601 시각 |
| `concept` | String | 사용자 입력 컨셉 |
| `guidanceMessage` | String | 엔진이 제안한 문구 |
| `confidence` | Double | 엔진 신뢰도 |
| `source` | String | `model` or `heuristic` |
| `acceptedForUI` | Bool | 디바운스/쿨다운 필터를 통과해 UI 반영됐는지 |
| `features` | Object | 프레임 숫자 피처 |

## features Object

| Key | Type | Description |
| --- | --- | --- |
| `faceDetected` | Bool | 얼굴 검출 여부 |
| `faceCenterX` | Double? | 얼굴 중심 X (0~1) |
| `faceCenterY` | Double? | 얼굴 중심 Y (0~1) |
| `faceSize` | Double? | 얼굴 너비 (0~1) |
| `saliencyX` | Double? | 주목 영역 중심 X (0~1) |
| `saliencyY` | Double? | 주목 영역 중심 Y (0~1) |
| `horizonAngle` | Double? | 수평선 기울기(라디안) |
| `brightness` | Double | 밝기 추정치 |
| `sharpness` | Double | 선명도 추정치 |
| `sceneType` | String | 씬 타입(raw value) |
