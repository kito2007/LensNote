# LensNote Backlog

## Milestone 1: MVP Completion

### P0

- [x] Unify or intentionally bridge the camera save flow and map photo data flow.
  Done: `FetchPhotoPinsUseCase` + `DIContainer.makeMapViewModel()` bridge camera saves to map pins. `FilePhotoRepository` persists across restarts. (2026-03-31 / 2026-04-01)

- [x] Ensure captured photos include the right metadata story for map display.
  Done: `LocationProvider` injected into `CameraViewModel`; coordinate auto-resolved on save; `NSLocationWhenInUseUsageDescription` added; `locationWarningToast` shown when coordinate is nil. (2026-03-31)
  Risk: runtime persistence validation not yet confirmed in simulator — manual QA still needed.

- [ ] Finish the camera onboarding and transition flow end-to-end.
  Why: the user should be able to enter intent and reach live guidance without friction.
  Owner: `lensnote-designer` -> `lensnote-ios-engineer` -> `lensnote-simulator-qa`

- [ ] Stabilize the live guidance UX.
  Why: composition feedback should be understandable and calm rather than noisy.
  Owner: `lensnote-designer` -> `lensnote-ios-engineer` -> `lensnote-simulator-qa`

- [ ] Make the map tab feel like a real product screen, including permission handling and empty states.
  Why: the map is a defining differentiator of LensNote.
  Owner: `lensnote-designer` -> `lensnote-ios-engineer` -> `lensnote-simulator-qa`

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
- [ ] Improve map pin detail cards and browsing flow.
- [ ] Decompose oversized feature files where the payoff is clear, especially `MapView.swift`.
- [ ] Add stronger error and permission recovery messaging.
- [ ] Expand simulator QA scenarios for home, camera, and map flows.

## Milestone 3: Demo Readiness And Polish

- [ ] Tighten Home screen messaging so the product story is instantly clear.
- [ ] Improve Profile or remove placeholder feeling if it stays in the demo.
- [ ] Collect stable screenshots and demo paths.
- [ ] Perform final regression pass across key flows.

## Recommended Execution Order

1. Resolve saved photo and map data flow strategy.
2. Finish camera flow and live guidance usability.
3. Strengthen map experience around the chosen data strategy.
4. Expose filter recommendation more clearly.
5. Improve runtime testability with accessibility identifiers and simulator scenarios.
6. Polish and demo preparation.
