# Todoist Integration — Implementation Result

**Date:** 2026-03-16
**Branch:** `feat/todoist-integration`
**Status:** Complete — ready for manual smoke testing and merge

---

## Summary

All 12 tasks from the implementation plan executed successfully. 11 commits on `feat/todoist-integration`. Clean build (`** BUILD SUCCEEDED **`), zero errors, zero Todoist-related warnings. 665 lines added across 12 files (5 new, 7 modified).

## Commits

| SHA | Message |
|-----|---------|
| `38292c9` | build: add network client entitlement for Todoist API |
| `bc526df` | feat(todoist): add TodoistProject and TodoistTask models |
| `17ce4ea` | feat(todoist): add KeychainHelper for API token storage |
| `3fb0982` | feat(todoist): add TodoistService API client |
| `e4236ec` | feat(todoist): add TodoistManager orchestrator |
| `07824a2` | feat(todoist): wire TodoistManager into TBTimer and state machine |
| `db7dc70` | feat(todoist): add Tasks tab with project-grouped task list |
| `e206a51` | feat(todoist): add task bar above timer controls in popover |
| `6e222f9` | feat(todoist): add Todoist section to Settings (token, verify, disconnect) |
| `091edf8` | feat(todoist): show task name in menu bar when timer running |
| `1f71f1c` | fix(todoist): add workMinutes validation guard in logPomodoro |

## Files

### New (5)

| File | LOC | Purpose |
|------|-----|---------|
| `TomoBar/Todoist/TodoistModels.swift` | 27 | TodoistProject, TodoistTask Codable DTOs |
| `TomoBar/Todoist/KeychainHelper.swift` | 75 | Security framework wrapper for API token |
| `TomoBar/Todoist/TodoistService.swift` | 77 | URLSession API client (projects, tasks, comments) |
| `TomoBar/Todoist/TodoistManager.swift` | 238 | Orchestrator: token, selection, counts, logging |
| `TomoBar/Views/TasksView.swift` | 129 | Tasks tab UI with project grouping |

### Modified (7)

| File | Change |
|------|--------|
| `TomoBar.entitlements` | +`com.apple.security.network.client` |
| `Timer.swift` | +`todoist` property, Combine forwarding, import |
| `TimerStateMachine.swift` | +`todoist.logPomodoro()` in onIntervalCompleted |
| `TimerDisplay.swift` | +task name suffix in updateStatusBar() |
| `View.swift` | +`.tasks` enum case, picker tab, GroupBox case, task bar |
| `SettingsView.swift` | +Todoist section (token, verify, disconnect, toggle) |
| `project.pbxproj` | +file refs for 5 new files |

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Build succeeds with zero errors | ✅ |
| KeychainHelper save/load/delete | ✅ |
| TodoistService fetch projects/tasks, post comments | ✅ |
| TasksView grouped by project with selection | ✅ |
| SettingsView Todoist section | ✅ |
| Task bar in popover | ✅ |
| Timer completion triggers comment posting (non-blocking) | ✅ |
| Pomodoro counts persist via @AppStorage | ✅ |
| Menu bar shows task name | ✅ |
| Tasks tab empty state with "Go to Settings" | ✅ |
| Network entitlement added | ✅ |

## Design Decisions

### @MainActor omitted from TodoistManager

The plan called for `@MainActor` on `TodoistManager`. During implementation, this caused actor isolation conflicts: `TBTimer` (non-isolated) owns `TodoistManager` and accesses it synchronously from state machine handlers and Combine sinks. Adding `@MainActor` would require all access points to use `await`, breaking the existing synchronous API surface.

**Mitigation:** All `@Published` mutations happen inside `Task { }` blocks that inherit MainActor context from their callers (SwiftUI views and main-queue DispatchQueue handlers). The `logPomodoro` path uses `Task.detached` for network I/O but does NOT mutate any `@Published` properties — it only reads captured values and calls the API service.

### `let todoist` → `var todoist`

Changed from `let` to `var` in TBTimer to support SwiftUI binding paths like `$timer.todoist.showTaskInMenuBar`. Swift requires `var` for writable key paths through property wrappers.

### print() for error logging

`TBLogger.append(event:)` requires a `TBLogEvent` conformer (protocol with `type` and `timestamp`). Creating a dedicated log event class for a single failure message would be over-engineering. Using `print()` matches other non-critical logging patterns in the codebase.

## Manual Smoke Test Checklist

- [ ] Launch app — menu bar icon appears, no crash
- [ ] Open popover — task bar shows "Select a task..." above controls
- [ ] Go to Settings — Todoist section visible with token input
- [ ] Enter valid API token, click Verify — status changes to "Connected"
- [ ] Enter invalid token, click Verify — shows "Invalid token" in red
- [ ] Switch to Tasks tab — tasks load, grouped by project
- [ ] Select a task — checkmark appears, task bar updates with name
- [ ] Tap selected task again — deselects (checkmark removed)
- [ ] Start a work interval — menu bar shows time + task name
- [ ] Complete a work interval — comment posted to Todoist task, count increments
- [ ] Check task bar — shows "🍅 1" badge
- [ ] Relaunch app — selected task + count persists
- [ ] Reset count button — count goes to 0, badge disappears
- [ ] Settings > toggle "Show task in menu bar" off — task name hidden from menu bar
- [ ] Disconnect in Settings — token cleared, Tasks tab shows empty state
- [ ] Refresh button in Tasks tab — reloads tasks from API

## Known Limitations (v1)

Per spec "Out of Scope":
- No OAuth flow — personal API token only
- No task completion from TomoBar
- No creating new tasks
- No search/filter in task list
- No due date display
- No offline queue for failed comments
- No syncing pomodoro counts with Todoist labels/metadata
