# CLAUDE.md

Work style: telegraph; noun-phrases ok; drop grammar; min tokens

## Project Overview

TomoBar — macOS menu bar pomodoro timer. SwiftUI popover with tabs (Tasks, Intervals, Settings, Controls, Sounds). Currently adding Todoist integration: task picker, auto-log pomodoros as comments, session tracking. Personal use, not App Store. Forked from ArtemYurov/TomoBar.

Bundle ID: `org.yurov.tomobar`. Sandboxed with Apple Events + network client entitlements.

## Architecture

**MVVM + Combine.** Central state in `TBTimer: ObservableObject`, passed via `@EnvironmentObject`.

- **State machine:** SwiftState (`TBStateMachine`) with states `idle/work/shortRest/longRest` and events `startStop/confirmedNext/skipEvent/intervalCompleted/sessionCompleted`. Defined in `State.swift`, routes+handlers in `Timer/TimerStateMachine.swift`.
- **Timer:** `DispatchSourceTimer` in `Timer/TimerCore.swift`. Wall-clock based (finishTime - now), not tick-counting. Handles App Nap/sleep gracefully.
- **Settings:** `@AppStorage` on `TBTimer` for all persisted prefs. Presets stored as JSON-encoded `[TimerPreset]`.
- **Notifications:** `TBNotify` coordinator (`Notify.swift`) — system, custom window, or fullscreen mask. Auto-transition logic depends on alert mode + notify style.
- **Audio:** `TBPlayer` with AVAudioPlayer for windup/ding/ticking sounds.
- **DND:** ScriptingBridge → AppleScript Shortcut for Focus Mode toggle.

**Todoist integration layer** (new):
- `Todoist/TodoistService.swift` — URLSession API client (projects, tasks, comments)
- `Todoist/TodoistModels.swift` — `TodoistTask`, `TodoistProject` structs
- `Todoist/KeychainHelper.swift` — Security framework wrapper (save/load/delete token)
- `Todoist/TodoistManager.swift` — orchestrator: selected task, pomodoro counts, auto-logging
- `Views/TasksView.swift` — task list UI grouped by project

Full spec: `.friday/specs/todoist-integration.md`

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI (popover hosted in NSHostingView)
- **State:** SwiftState (state machine), Combine (@Published, ObservableObject)
- **Persistence:** @AppStorage (UserDefaults), Keychain (Security framework)
- **Network:** URLSession (Todoist REST API v2)
- **Audio:** AVFoundation (AVAudioPlayer)
- **Dependencies:** LaunchAtLogin, Sparkle (optional, behind `#if SPARKLE`), KeyboardShortcuts
- **Build:** Xcode (.xcodeproj), no SPM package manifest

## Commands

```bash
# Build (requires Xcode + license agreement)
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build

# Open in Xcode (preferred for building/running)
open TomoBar.xcodeproj

# Clean build
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar clean build
```

No test target currently. No CLI build scripts. Build and run via Xcode.

## General Protocol
- This project is managed by Friday. Specs, plans, and past decisions live in `.friday/`.
- PRs: use `gh pr view/diff` (no URLs).
- "Make a note" => edit CLAUDE.md (shortcut; not a blocker).
- Need upstream file: stage in `/tmp/`, then cherry-pick; never overwrite tracked.
- Bugs: add regression test when it fits.
- Keep files <~500 LOC; split/refactor as needed.
- Commits: Conventional Commits (`feat|fix|refactor|build|ci|chore|docs|style|perf|test`).
- Prefer end-to-end verify; if blocked, say what's missing.
- New deps: quick health check (recent releases/commits, adoption).
- Web: search early; quote exact errors; prefer 2024–2025 sources;
- Style: telegraph. Drop filler/grammar. Min tokens (global AGENTS + replies).

## Project Context

Specs, plans, and visual references from all development cycles live in `.friday/`:
- **Specs:** `.friday/specs/` — feature specs, technical decisions, design docs
- **Implementation plans:** `.friday/impl-plans/` — task breakdowns, acceptance criteria, result reports
- **Visual references:** `.friday/visual-refs/` — mockups, screenshots, UI references

Read these before starting new work. Past specs contain architectural decisions that shouldn't be re-debated.

## Key Context & Lessons Learned
<!-- Anything a fresh CC session needs to know and remember about this project -->

## Make It Yours
This is a starting point. Add your own conventions, style, and rules as you figure out what works.
