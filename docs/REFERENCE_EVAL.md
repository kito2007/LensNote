# 레퍼런스 인식 정확도 평가셋 (Reference Perception Eval)

## 목적

LensNote의 핵심 기능 — "레퍼런스 사진의 **피사체 크기·위치·앵글**을 라이브에서 재현하도록 코칭" — 의
품질을 **느낌이 아니라 숫자**로 측정한다.

코칭은 두 단계다:
1. **인식(perception)** — 레퍼런스/라이브 프레임에서 사람의 크기·위치·앵글을 제대로 읽는가? ← **이 평가셋이 검증**
2. **코칭(guidance)** — 그게 맞다 치고, 지시 방향·타이밍이 맞는가?

1번이 틀리면 2번은 100% 틀린다. 그래서 인식 정확도부터 측정한다.

## 폴더 구조

레포 루트(`LensNote/LensNote/`)의 `EvalAssets/`. **앱·테스트 번들에 포함되지 않는다**(시뮬레이터
테스트가 호스트 Mac 경로에서 직접 읽음).

```
EvalAssets/
  references/          ← 레퍼런스 이미지(사용자가 넣음). jpg/png/heic
    ref_001.jpg
    ref_002.jpg
    ...
  labels.json          ← ground truth 라벨(채점 기준). 아래 스키마.
  labels.draft.json    ← 분석기 출력으로 자동 생성된 초안(검수 출발점). 자동 생성물.
  _previews/           ← 분석기가 그린 박스 미리보기(검수용). 자동 생성물.
```

## 워크플로우 (라벨링 노동 최소화)

좌표를 손으로 적지 않는다. **분석기 초안 → 검수/교정** 방식.

1. **사진 투입** — 좋아하는 레퍼런스 20~30장을 `references/`에 넣는다. (인물 위주 권장 — 셀피/반신/전신)
2. **초안 생성** — Claude가 `generateLabelDrafts` 하니스 실행 →
   - `labels.draft.json`: 분석기가 추출한 박스/앵글을 라벨 초안으로 기록
   - `_previews/`: 각 이미지에 **분석기가 인식한 박스를 그려서** 저장 (눈으로 맞는지 확인용)
3. **검수/교정** — `_previews/`를 보고, `labels.draft.json`을 `labels.json`으로 복사한 뒤 **틀린 것만 교정**.
   각 항목 `verified: true`로 표시. (맞으면 박스 그대로 두고 verified만 켜면 됨)
4. **채점** — Claude가 `scoreAccuracy` 하니스 실행 → 인식 정확도 리포트(축별 %)를 콘솔에 출력.
5. **튜닝 반복** — 낮은 축을 보고 `ShotRecipeAnalyzer` 룰/임계값 조정 → 재채점.

## 라벨 스키마 (`labels.json`)

```jsonc
{
  "version": 1,
  "tolerances": {
    "coverage": 0.10,   // 분석기 coverage vs 라벨 박스 면적 허용 오차(절대값)
    "iou": 0.5          // 박스 위치 정확으로 인정할 최소 IoU
  },
  "items": [
    {
      "image": "ref_001.jpg",   // references/ 기준 파일명
      "verified": true,          // 검수 완료된 항목만 채점에 포함
      "subjectBox": {            // 사람 영역. 정규화 0~1, top-left origin. 사람 없으면 null
        "x": 0.20, "y": 0.08, "width": 0.55, "height": 0.84
      },
      "cameraAngle": "eyeLevel", // highAngle | eyeLevel | lowAngle | null(미상)
      "category": "fullBody",    // (선택) closeUp | halfBody | fullBody | landscape — 정보용
      "notes": ""                // (선택) 특이사항
    }
  ]
}
```

### 좌표 규약
- `subjectBox`는 **정규화(0~1) + top-left origin**. `ShotRecipe.subjectBoundingBox`(CodableRect)와 동일.
- 화면 왼쪽 위가 (0,0), 오른쪽 아래가 (1,1). `x,y`는 박스 좌상단, `width,height`는 박스 크기.
- 사람이 없는 레퍼런스(순수 풍경)는 `subjectBox: null`.

## 채점 항목 (축별)

검수된(`verified:true`) 항목에 대해 `ShotRecipeAnalyzer` 출력과 비교:

| 축 | 정답 조건 |
|---|---|
| **presence** | 분석기 박스 유무 == 라벨 박스 유무 (사람 검출 여부) |
| **coverage** | \|분석기 subjectCoverage − 라벨 박스 면적\| ≤ `tolerances.coverage` |
| **position(IoU)** | IoU(분석기 박스, 라벨 박스) ≥ `tolerances.iou` |
| **angle** | 분석기 cameraAngle == 라벨 cameraAngle |

리포트 예시:
```
=== Reference Perception Accuracy (n=24 verified) ===
presence   23/24  (95.8%)
coverage   17/24  (70.8%)
position   15/24  (62.5%)   ← IoU
angle      11/24  (45.8%)   ← 라이브 angle 약점과 연결
overall    66/96  (68.8%)
```

→ 이렇게 나오면 "느낌상 10%"가 "측정된 68.8%, 특히 angle 45.8%"로 바뀌고, **angle 룰부터 손보면 된다**가 명확해진다.

## 하니스 실행

테스트 타겟의 `ReferenceAccuracyTests`(시뮬레이터, 호스트 경로 직접 읽기):

```bash
# 초안 + 미리보기 생성 (사진 넣은 뒤 1회)
xcodebuild test -scheme LensNote -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LensNoteTests/ReferenceAccuracyTests/generateLabelDrafts

# 정확도 채점 (labels.json 검수 후, 그리고 룰 튜닝할 때마다)
xcodebuild test -scheme LensNote -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LensNoteTests/ReferenceAccuracyTests/scoreAccuracy
```

`labels.json`이 없거나 비어 있으면 `scoreAccuracy`는 조용히 통과(스킵)한다 — 데이터 투입 전엔 일반 테스트에 영향 없음.

## 범위 (현재)

- **인물 중심**(셀피/반신/전신). 풍경·사물 구도는 후순위.
- 인식(perception)만 측정. 코칭(guidance) 방향/타이밍 평가셋은 인식 정확도가 올라온 뒤 추가.
