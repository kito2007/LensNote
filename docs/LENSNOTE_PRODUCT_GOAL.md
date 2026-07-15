# LensNote Product Goal

## Final Target

LensNote should become a polished, demo-ready SwiftUI iOS app with:

- MVVM architecture
- a CoreML-powered camera assistant
- composition guidance during capture
- 레퍼런스/컨셉에서 추출한 색보정 프리셋을 **라이브 프리뷰와 저장 사진 모두에 실제 적용**(WYSIWYG). 캡처 설정(ISO/조리개/초점거리)은 필터 범위에서 제외.
  - 진행: Path A(저장 사진 적용) + Path B(MTKView 라이브 프리뷰) 코드 완료·빌드 검증. 실기기 성능(≥30fps)·시각(방향/WYSIWYG) 게이트만 잔여.
- saved photo persistence with metadata
- a map-based photo browsing experience instead of a grid gallery

## Product Positioning

LensNote is not a generic photo utility.

It should feel like:

- a camera-first creative assistant
- a place-based memory browser
- a coherent and visually intentional SwiftUI app

## Non-Negotiables

- Follow MVVM consistently
- Preserve the existing `Application` / `Domain` / `Features` / `DesignSystem` structure unless a change is justified
- Keep camera performance stable
- Treat CoreML guidance as assistive, clear, and non-chaotic
- Keep map browsing central to the product experience
- Prefer concrete runtime validation over purely theoretical completion claims

## Definition Of Done

LensNote is in a strong MVP/demo state when:

1. A user can move through Home -> Camera -> concept flow -> live guidance -> save result without obvious breakage.
2. Saved photo data and map browsing tell a coherent story.
3. The map tab is meaningful, not a placeholder.
4. The visual design feels cohesive across Home, Camera, and Map.
5. Core user flows are validated through simulator QA and, where necessary, flagged for real-device follow-up.
