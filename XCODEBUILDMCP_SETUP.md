# XcodeBuildMCP Setup For LensNote

LensNote is configured to use XcodeBuildMCP for simulator-driven runtime testing.

This repo already includes:

- repo-scoped defaults in [`.xcodebuildmcp/config.yaml`](/Users/parktaeyeong/SideProjects/LensNote/LensNote/.xcodebuildmcp/config.yaml)
- a Claude Code simulator testing agent in [`.claude/agents/lensnote-simulator-qa.md`](/Users/parktaeyeong/SideProjects/LensNote/LensNote/.claude/agents/lensnote-simulator-qa.md)

## What This Setup Is For

Use XcodeBuildMCP when you want Claude to:

- build and launch LensNote in iOS Simulator
- inspect the visible UI tree
- tap, swipe, type, and navigate through app flows
- capture screenshots, logs, and videos
- validate runtime behavior after code changes

## Repo Defaults

The project config sets these stable defaults:

- project path: `./LensNote.xcodeproj`
- scheme: `LensNote`
- configuration: `Debug`
- platform: `iOS`
- bundle id: `com.PTY.LensNote`
- derived data path: `./.xcodebuildmcp/DerivedData`
- workflows: `simulator`, `ui-automation`, `logging`

Simulator name is intentionally not pinned in config, because available simulator models can vary by local Xcode installation. The testing agent should call `list_sims` and pick a valid iPhone simulator when needed.

## Local Requirements

Based on the upstream project docs, you should have:

- macOS with Xcode installed
- Node.js 18+
- access to `npx`

Primary source:
[getsentry/XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP)

## Recommended Claude Code Setup

The `lensnote-simulator-qa` agent already includes an inline XcodeBuildMCP server definition, so it can start the MCP server itself.

If you also want XcodeBuildMCP available outside that subagent, run:

```bash
claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@2.2.1 mcp
```

That command comes from the upstream README:
[XcodeBuildMCP README](https://github.com/getsentry/XcodeBuildMCP)

After adding it, restart Claude Code or reload MCP servers if needed.

## How To Use It

Example prompts:

```text
Use lensnote-simulator-qa to build and run LensNote in Simulator, open the camera tab, and tell me whether the initial concept flow is usable.
```

```text
Use lensnote-simulator-qa to validate the map tab in Simulator.
Check launch behavior, permission messaging, and capture screenshots of the empty state.
```

```text
Use lensnote-simulator-qa to regression test the floating dock after my latest UI changes.
Findings first.
```

## Good Prompt Pattern

When you ask Claude to use the simulator agent, include:

- the target flow
- what success looks like
- any constraints
- what evidence you want back

Example:

```text
Use lensnote-simulator-qa to test the camera onboarding flow.
Success means I can move from Home to Camera, enter a concept, and reach the live camera screen without broken layout.
Give me findings first, then screenshots and blocked cases.
```

## Notes

- LensNote currently has no committed test target, so this setup is especially useful for runtime regression checks.
- Camera capture quality, device sensors, and some permissions can behave differently in Simulator than on a real device.
- For flows that need real camera input or hardware-specific behavior, use this agent for partial validation and then confirm on a physical device.
