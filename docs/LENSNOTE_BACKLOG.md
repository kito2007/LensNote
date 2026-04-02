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

- [ ] **전체 디자인 개선** ← 우선순위 상향 (2026-04-01)
  Why: 맵에 사진이 많아지면 핀 식별이 어렵고, 각 화면의 시각 언어가 아직 불완전함. 테스트 편의성을 위해서도 필요.
  Scope:
    - ~~Map: 핀 상세 카드 개선, 빈 상태 화면, 권한 안내 화면~~ ✅ Done (2026-04-02)
    - Camera: 라이브 뷰 어시스턴트 패널 레이아웃, 구도 오버레이 정리
    - 전체: dark cinematic + cyan accent 언어 통일
  Owner: `lensnote-designer` → `lensnote-ios-engineer` → `lensnote-simulator-qa`

- [ ] Finish the camera onboarding and transition flow end-to-end.
  Why: the user should be able to enter intent and reach live guidance without friction.
  Note: 선택 화면 → 텍스트/레퍼런스/수동 → 라이브 뷰 전환은 구현됨. 레퍼런스 사진 분석 UX, 분석 중 상태 표시 등 세부 완성 필요.
  Owner: `lensnote-designer` → `lensnote-ios-engineer` → `lensnote-simulator-qa`

- [ ] Stabilize the live guidance UX.
  Why: composition feedback should be understandable and calm rather than noisy.
  Owner: `lensnote-designer` → `lensnote-ios-engineer` → `lensnote-simulator-qa`

- [x] Make the map tab feel like a real product screen, including permission handling and empty states.
  Done: 서브뷰 테마 통일, PermissionOverlayView 격상, MapEmptyStateView 추가, 맵 스타일 정리, PinCardView source 뱃지. (2026-04-02)

### P1

- [ ] Make concept input clearly influence filter recommendation or preset selection in a visible way.
  Why: the app promise includes filter guidance, not just hidden internal state.
  Owner: `lensnote-planner` -> `lensnote-designer` -> `lensnote-ios-engineer`

- [ ] Improve capture result feedback after saving a photo.
  Why: users need confidence that the shot was saved and connected to the LensNote flow.
  Owner: `lensnote-designer` -> `lensnote-ios-engineer`

- [ ] Add accessibility identifiers or stable labels to key UI controls for simulator automation.
  Why: this makes XcodeBuildMCP testing more reliable.
  Owner: `lensnote-ios-engineer`

## Milestone 2: Quality And Product Depth

- [ ] Refine filter recommendation logic and visible presentation.
- [x] Improve map pin detail cards and browsing flow.
  Done: PinCardView에 source 뱃지, 56pt 썸네일, cardLarge radius 적용. SidePanelList와 상호 배타 표시. (2026-04-02)
- [ ] Decompose oversized feature files where the payoff is clear, especially `MapView.swift`.
- [ ] Add stronger error and permission recovery messaging.
- [ ] Expand simulator QA scenarios for home, camera, and map flows.

## Milestone 3: Demo Readiness And Polish

- [ ] Tighten Home screen messaging so the product story is instantly clear.
- [ ] Improve Profile or remove placeholder feeling if it stays in the demo.
- [ ] Collect stable screenshots and demo paths.
- [ ] Perform final regression pass across key flows.

## Recommended Execution Order

1. ~~Resolve saved photo and map data flow strategy.~~ ✅ Done
2. **전체 디자인 개선** (~~맵~~ ✅ → 카메라 → 홈 순서) ← 현재 여기
3. Finish camera flow and live guidance usability.
4. Strengthen map experience around the chosen data strategy.
5. Expose filter recommendation more clearly.
6. Improve runtime testability with accessibility identifiers and simulator scenarios.
7. Polish and demo preparation.
