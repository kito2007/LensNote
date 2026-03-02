# CompositionAssist Model Schema

LensNote 카메라 어시스트 모델(`CompositionAssist`)의 입력/출력 스키마 정의입니다.
앱 코드 기준 매핑은 `/Users/parktaeyeong/LensNote/LensNote/Features/Camera/CompositionGuidanceEngine.swift`에 있습니다.

## Input Features

모든 좌표는 정규화 값(0.0~1.0)입니다.

| Canonical Key | Type | Range | Description | Aliases |
| --- | --- | --- | --- | --- |
| `face_center_x` | Double | 0.0~1.0 | 얼굴 중심 X | `face_x` |
| `face_center_y` | Double | 0.0~1.0 | 얼굴 중심 Y | `face_y` |
| `face_size` | Double | 0.0~1.0 | 얼굴 바운딩박스 너비 | `face_width` |
| `face_detected` | Int64 | 0 or 1 | 얼굴 검출 여부 | `has_face` |
| `saliency_x` | Double | 0.0~1.0 | 주목 객체 중심 X | `attention_x` |
| `saliency_y` | Double | 0.0~1.0 | 주목 객체 중심 Y | `attention_y` |
| `horizon_angle` | Double | -pi~pi | 수평선 기울기(라디안) | `roll` |
| `brightness` | Double | 0.0~1.0 | 프레임 밝기 추정치 | `exposure` |
| `sharpness` | Double | 0.0~1.0(권장) | 선명도 추정치 | `blur_score` |
| `scene_type` | Int64 | 0~6 | 씬 타입 인덱스 | `scene` |

### scene_type Index

- `0`: portrait
- `1`: landscape
- `2`: city_street
- `3`: food
- `4`: night
- `5`: pet
- `6`: etc

## Output Features

| Canonical Key | Type | Description | Aliases |
| --- | --- | --- | --- |
| `guidance_text` | String | 사용자에게 직접 노출할 가이드 문구 | - |
| `guidance_code` | Int64 | 앱 내부 가이드 코드(텍스트 대체용) | - |
| `confidence` | Double | 예측 신뢰도(0.0~1.0) | `score` |

## Output Priority

1. `guidance_text`가 있으면 우선 사용
2. 없으면 `guidance_code`를 앱 문구로 매핑
3. `confidence`가 없으면 앱 기본값 사용

## Notes

- 모델 입력명은 소문자 스네이크 케이스를 권장합니다.
- 앱은 일부 별칭(alias)을 허용하지만, 학습/배포 파이프라인은 canonical key를 표준으로 유지하세요.
- 미정의 입력 키는 앱에서 `0`으로 채웁니다.
