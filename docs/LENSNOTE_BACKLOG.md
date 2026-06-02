# LensNote Backlog

## Milestone 1: MVP Completion

### P0

- [x] Unify or intentionally bridge the camera save flow and map photo data flow.
  Done: `FetchPhotoPinsUseCase` + `DIContainer.makeMapViewModel()` bridge camera saves to map pins. `FilePhotoRepository` persists across restarts. (2026-03-31 / 2026-04-01)

- [x] Ensure captured photos include the right metadata story for map display.
  Done: `LocationProvider` injected into `CameraViewModel`; coordinate auto-resolved on save; `NSLocationWhenInUseUsageDescription` added; `locationWarningToast` shown when coordinate is nil. (2026-03-31)
  Risk: runtime persistence validation not yet confirmed — manual QA still needed.

- [x] Fix camera live view tab bar overlap.
  Done: `FloatingDockBar` hidden when `isLiveCamera = true` via binding in `CameraView` / `RootView`. Real-device verified. (2026-04-01)

- [x] **전체 디자인 개선** ← 우선순위 상향 (2026-04-01)
  Why: 맵에 사진이 많아지면 핀 식별이 어렵고, 각 화면의 시각 언어가 아직 불완전함. 테스트 편의성을 위해서도 필요.
  Scope:
    - ~~Map: 핀 상세 카드 개선, 빈 상태 화면, 권한 안내 화면~~ ✅ Done (2026-04-02)
    - ~~Camera: 라이브 뷰 어시스턴트 패널 레이아웃, 구도 오버레이 정리~~ ✅ Done (2026-04-05)
    - ~~Home: Quick Shot 수직 재배치, Map Gallery preview, Recent Sessions 썸네일+gear 라벨~~ ✅ Done (2026-04-18)
  Owner: `lensnote-designer` → `lensnote-ios-engineer` → `lensnote-simulator-qa`

- [x] Finish the camera onboarding and transition flow end-to-end.
  Done: 레퍼런스 분석을 3단계 애니메이션(톤/컬러/프리셋, ~1.8s)으로 시각화, 완료 후 프리셋 요약 카드 + 확정 CTA 노출, 라이브 뷰 REF 썸네일에 실제 레퍼런스 사진 반영. (2026-04-17)
  Note: 실기기 체감 시간 튜닝은 별도 추적.

- [x] Stabilize the live guidance UX.
  Done: `activeGuidanceHint` 통합 퍼블리셔 + CoreML 힌트 안정화(0.9s stability / 1.6s min display) + Vision fallback + 캡처 바 위 글래스 배너 노출. (2026-04-17)
  Note: 실기기 체감 튜닝은 다음 세션 필요.

- [x] Make the map tab feel like a real product screen, including permission handling and empty states.
  Done: 서브뷰 테마 통일, PermissionOverlayView 격상, MapEmptyStateView 추가, 맵 스타일 정리, PinCardView source 뱃지. (2026-04-02)

### P1

- [x] Make concept input clearly influence filter recommendation or preset selection in a visible way.
  Done: `FilterPreset.forConcept(_:)` 단일 룰 추출(야경/인물/풍경까지 확장), `PresetSummaryView` 공용 추출, CameraConceptStepView에 suggestion chips + 실시간 preset preview 카드 + "{preset.name}으로 시작" CTA 반영. (2026-04-18)

- [x] Improve capture result feedback after saving a photo.
  Done: 저장 후 결과 카드(썸네일/위치명 역지오코딩/프리셋/ShotStyle + "지도에서 보기") + 실패 시 재시도. (Kiro Req 2, 2026-06-02)

- [x] Add accessibility identifiers or stable labels to key UI controls for simulator automation.
  Done: camera.*/dock.tab.*/map.pin.*/map.filter.* 식별자 부여. (Kiro Req 4, 2026-06-02)

## Milestone 2: Quality And Product Depth

- [ ] Refine filter recommendation logic and visible presentation.
- [x] Improve map pin detail cards and browsing flow.
  Done: PinCardView에 source 뱃지, 56pt 썸네일, cardLarge radius 적용. SidePanelList와 상호 배타 표시. (2026-04-02)
- [x] Decompose oversized feature files where the payoff is clear, especially `MapView.swift`.
  Done: `Features/Map/Views/` 서브뷰 분리(PinAnnotation/Cluster/SidePanel/PinCard/PermissionOverlay/EmptyState/Loading) + MapRegionFilter 추출. (Kiro Req 7, 2026-06-02)
- [ ] Add stronger error and permission recovery messaging.
- [ ] Expand simulator QA scenarios for home, camera, and map flows.

## Milestone 3: Demo Readiness And Polish

- [ ] Tighten Home screen messaging so the product story is instantly clear.
- [x] Improve Profile or remove placeholder feeling if it stays in the demo.
  Done: "Coming soon" 제거, 촬영 통계(총촬영/최다 ShotStyle/최다 Preset) + 빈/에러 상태. (Kiro Req 5, 2026-06-02)
- [ ] Collect stable screenshots and demo paths.
- [ ] Perform final regression pass across key flows.

## Recommended Execution Order

1. ~~Resolve saved photo and map data flow strategy.~~ ✅ Done
2. ~~**전체 디자인 개선**~~ (~~맵~~ ✅ → ~~카메라~~ ✅ → ~~홈~~ ✅) ✅ Done (2026-04-18)
3. ~~Finish camera flow and live guidance usability.~~ ✅ Done (2026-04-17)
4. Strengthen map experience around the chosen data strategy.
5. ~~Expose filter recommendation more clearly.~~ ✅ Done (2026-04-18)
6. Improve runtime testability with accessibility identifiers and simulator scenarios. ← 현재 여기
7. Polish and demo preparation.
