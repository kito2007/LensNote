See @docs/LENSNOTE_PRODUCT_GOAL.md for the final product target.
See @docs/LENSNOTE_BACKLOG.md for the prioritized execution backlog.
See @docs/ACTIVE_CONTEXT.md for the current handoff state and next recommended step.

# LensNote Claude Guide

## Product Context

LensNote is a SwiftUI iOS app with two core experiences:

- Camera assistant: helps the user shoot better photos with composition guidance and concept-based filter presets.
- Map gallery: shows captured photos on a map using location metadata instead of a traditional grid gallery.

The product should feel like a camera-first creative tool, not a generic photo app.

## Current Architecture

- `LensNote/Application`: app entry, DI container, root tab structure.
- `LensNote/Domain`: entities, repositories, and use cases.
- `LensNote/Features/Camera`: AVFoundation camera flow, CoreML/Vision guidance, capture steps, dataset tooling.
- `LensNote/Features/Map`: photo-library permission handling, map pins, clustering, card UI.
- `LensNote/DesignSystem`: shared theme tokens and reusable UI components.
- `LensNote/Resources`: model schema and camera/data documentation.

Architectural pattern:

- This project should follow MVVM.
- SwiftUI `View` types should focus on rendering and user interaction wiring.
- `ObservableObject` view models should own presentation state and coordinate feature logic.
- Domain types, repositories, and use cases should hold business and persistence concerns.
- Services and engines may support view models, especially for camera, Vision, and CoreML work.

Current boundary note:

- Camera save flow uses the domain repository and `SavePhotoUseCase`.
- Map currently reads from `PHPhotoLibrary` directly and builds its own `PhotoPin` model.
- Do not assume camera persistence and map data are already unified.

Important files:

- `LensNote/Features/Camera/CameraViewModel.swift`
- `LensNote/Features/Camera/CompositionGuidanceEngine.swift`
- `LensNote/Features/Map/MapView.swift`
- `LensNote/DesignSystem/LensNoteTheme.swift`
- `LensNote/Application/RootView.swift`

## External Design Reference

The primary external design reference for LensNote lives at:

- `/Users/parktaeyeong/SideProjects/LensNote/stitch_ai_camera_assistant`

Relevant reference files and folders:

- `/Users/parktaeyeong/SideProjects/LensNote/stitch_ai_camera_assistant/lensnote_prd.html`
- `/Users/parktaeyeong/SideProjects/LensNote/stitch_ai_camera_assistant/stitch_ai_camera_assistant/ai_camera_assistant/`
- `/Users/parktaeyeong/SideProjects/LensNote/stitch_ai_camera_assistant/stitch_ai_camera_assistant/home_entry_point/`
- `/Users/parktaeyeong/SideProjects/LensNote/stitch_ai_camera_assistant/stitch_ai_camera_assistant/map_gallery/`
- `/Users/parktaeyeong/SideProjects/LensNote/stitch_ai_camera_assistant/stitch_ai_camera_assistant/photo_details_analysis/`
- `/Users/parktaeyeong/SideProjects/LensNote/stitch_ai_camera_assistant/stitch_ai_camera_assistant/lensnote_logic/DESIGN.md`

When doing design work, prefer this reference over generic design choices.
If the user-provided path is slightly wrong, use the existing path above as the source of truth.

## Engineering Rules

- Follow MVVM consistently when adding or refactoring code.
- Preserve layering: view/UI changes stay in `Features` or `DesignSystem`; persistence and save flows stay behind `Domain`.
- Keep camera changes performance-aware. Respect the existing session queues, throttling, and MainActor boundaries.
- Treat CoreML/Vision guidance as a user-facing assistant. Guidance should stay stable, understandable, and safe to ignore.
- Map work must preserve photo permission fallbacks and the "mock pins when unavailable" behavior unless intentionally changed.
- Reuse `LensNoteTheme` before introducing new colors, spacing, or typography patterns.
- Avoid broad refactors unless the task clearly needs them.
- If a task touches both saved-photo data and the map, verify which source of truth it should use before changing architecture.
- There is currently no committed test target in this repo. When validating work, prefer:
  1. build verification
  2. focused manual QA steps
  3. targeted automated tests only if a test target is added

## Delegation Policy

For larger tasks, split work in this order when useful:

1. `lensnote-planner`
2. `lensnote-designer`
3. `lensnote-ios-engineer`
4. `lensnote-simulator-qa`
5. `lensnote-qa`

Use each subagent for its specialty:

- `lensnote-planner`: feature scope, user stories, architecture options, acceptance criteria, implementation sequencing.
- `lensnote-designer`: camera UX, map UX, visual direction, copy, layout polish, accessibility, interaction details.
- `lensnote-ios-engineer`: SwiftUI, AVFoundation, Vision, CoreML, persistence, data flow, bug fixes, implementation.
- `lensnote-simulator-qa`: XcodeBuildMCP-based simulator testing, UI automation, build/run flows, screenshots, logs, and scenario validation.
- `lensnote-qa`: regression review, test plans, build checks, manual QA coverage, release-readiness review.

If a task spans multiple areas, prefer planner first and QA last.

Suggested default sequence for substantial work:

1. Ask `lensnote-planner` to define scope and acceptance criteria.
2. Ask `lensnote-designer` to refine UX and visual decisions if the task changes user-facing behavior.
3. Ask `lensnote-ios-engineer` to implement the change.
4. Ask `lensnote-simulator-qa` to run simulator-driven checks when the task affects UI, flows, permissions, or runtime behavior.
5. Ask `lensnote-qa` to review regressions and verification coverage.

## LensNote-Specific Expectations

- Prefer MVVM-shaped feature work:
  - `View`: layout, bindings, rendering, user actions
  - `ViewModel`: UI state, orchestration, async workflows, platform API coordination
  - `Domain/Service`: business rules, persistence, inference support, reusable logic
- Prefer XcodeBuildMCP for simulator build/run/UI automation work over raw `xcodebuild`, `simctl`, or ad hoc shell commands when validating runtime behavior.
- Repo-scoped XcodeBuildMCP defaults live in `.xcodebuildmcp/config.yaml`.
- Camera changes should account for:
  - concept input -> preset update
  - live guidance messaging
  - readiness-to-capture behavior
  - overlay stability
  - saved photo persistence
- Map changes should account for:
  - photo-library authorization states
  - location metadata availability
  - pin loading and selection
  - clustered vs single-pin presentation
- UI changes should preserve LensNote's current visual language:
  - dark cinematic surfaces
  - bright blue/cyan accent energy
  - rounded cards and floating controls
  - bold, editorial-feeling hero moments

## Output Preferences

When working on a task in this repo:

- explain tradeoffs briefly
- reference concrete files
- keep plans actionable
- surface risks early
- end with a short verification summary

## Continuity Workflow

- Treat `docs/ACTIVE_CONTEXT.md` as the canonical cross-session handoff file.
- At the end of substantial work, update `docs/ACTIVE_CONTEXT.md` with:
  - what changed
  - what is still pending
  - blockers or risks
  - exact next recommended task
  - verification status
- Keep `docs/LENSNOTE_BACKLOG.md` current when milestone status or priorities change.
- When asked to continue work in a new session, read the imported goal, backlog, and active context first, then resume from there.
