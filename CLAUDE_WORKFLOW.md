# Claude Code Workflow For LensNote

This project is set up to use four specialized subagents in Claude Code:

- `lensnote-planner`
- `lensnote-designer`
- `lensnote-ios-engineer`
- `lensnote-simulator-qa`
- `lensnote-qa`

They live in [`.claude/agents`](/Users/parktaeyeong/SideProjects/LensNote/LensNote/.claude/agents) and are tailored to LensNote's current SwiftUI, CoreML, camera, and map architecture.

## Recommended Working Loop

1. Plan the work
2. Refine the user experience
3. Implement the code
4. Run simulator-driven validation
5. Review regressions and verification

This keeps each prompt narrow and makes your process easy to explain in interviews:

- planner defines scope and acceptance criteria
- designer protects UX quality and visual consistency
- engineer focuses on implementation details
- simulator QA agent validates real runtime behavior in iOS Simulator
- QA checks regression risk and missing coverage

## Example Prompts

Use prompts like these in Claude Code:

### 1. Planning

`Use lensnote-planner to break down a feature that recommends a shooting spot on the live camera screen based on scene type and existing map history. I want scope, affected files, risks, and acceptance criteria.`

### 2. Design

`Use lensnote-designer to propose the UX for a live camera hint card that suggests composition and filter tone without covering too much of the preview. Keep LensNote's current visual language.`

### 3. Development

`Use lensnote-ios-engineer to implement the selected plan for improving the camera guidance overlay. Preserve performance and existing capture flow.`

### 4. QA

`Use lensnote-qa to review the camera overlay change for regressions, missing tests, and manual QA coverage. Findings first.`

### 5. Simulator QA

`Use lensnote-simulator-qa to build and run LensNote in the iOS Simulator, walk through the camera entry flow, capture screenshots, and tell me where the UX or runtime behavior breaks.`

## Good Task Splits For This App

- New camera assistant feature
  - planner: define user story, scope, and architecture impact
  - designer: decide overlay placement, copy, and interaction rules
  - engineer: implement AVFoundation, SwiftUI, or CoreML integration
  - simulator QA: run the camera flow in Simulator, inspect overlays, permissions, logs, and visible regressions
  - QA: verify permissions, stability, capture flow, and save behavior

- Map/gallery enhancement
  - planner: define whether the feature should use saved app data or `PHPhotoLibrary`
  - designer: define pin, card, cluster, and empty-state UX
  - engineer: implement data flow and map interactions
  - simulator QA: validate map launch, permission messaging, pin interactions, and screenshots in runtime
  - QA: verify permission states, missing geodata, and selection behavior

- Visual polish
  - planner: optional for larger UI work
  - designer: primary owner
  - engineer: apply SwiftUI changes
  - simulator QA: compare screenshots and runtime layout on target simulators
  - QA: verify accessibility and layout regressions

## Interview Framing

If you want to explain this setup in a job interview, a strong summary is:

`I don't use an agent as a single all-purpose coder. I split work into planning, design, implementation, and QA roles so the prompts stay focused, context stays smaller, and each stage has a clear output. In LensNote, that matters because camera guidance, CoreML logic, and map-based photo browsing each have different constraints.`

You can make that more concrete with points like:

- planning agent writes acceptance criteria before code starts
- design agent protects UX quality in SwiftUI screens
- implementation agent handles AVFoundation, Vision, CoreML, and data flow
- simulator QA agent drives the app in iOS Simulator with XcodeBuildMCP tools
- QA agent checks regressions and missing coverage, especially because this repo does not yet have a full test target

## Important Project Caveat

Right now, LensNote has two different photo data paths:

- camera capture saves through the app's domain repository
- map browsing reads from `PHPhotoLibrary` directly

That means any agent working on "saved photos on the map" should explicitly decide whether to keep those flows separate or unify them.
