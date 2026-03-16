# Todoist Integration Spec

**Status:** Draft
**Date:** 2026-03-16

## Overview

Add Todoist integration to TomoBar so users can select a task to focus on during pomodoros, auto-log completed work intervals as comments on the task, and track pomodoro counts per task.

Personal use only. No OAuth — personal API token via Todoist Settings > Integrations > Developer.

## API Surface

Todoist REST API v2. Bearer token auth. Three endpoints:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/rest/v2/projects` | Fetch all projects (for grouping) |
| GET | `/rest/v2/tasks` | Fetch active tasks |
| POST | `/rest/v2/comments` | Log pomodoro on selected task |

All calls via URLSession. No external dependencies.

## Entitlements

Add `com.apple.security.network.client` to `TomoBar.entitlements` (outbound network for API calls).

---

## Feature 1: API Token Setup

### Storage
- `KeychainHelper` struct — `save(token:)`, `load() -> String?`, `delete()`.
- Direct Security framework calls (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`).
- Service name: `"com.tomobar.todoist-token"`.

### Settings UI
- New "Todoist" section in `SettingsView`.
- `SecureField` for API token input.
- "Verify" button — calls `GET /rest/v2/projects` to validate token.
- Status indicator: `none` (no token), `verifying...`, `connected`, `invalid`.
- "Disconnect" button (visible when connected) — deletes token from Keychain, clears selected task.

### Tasks Tab Empty State
- When no token configured, Tasks tab shows:
  - "Connect Todoist to get started"
  - "Go to Settings" button that switches the segmented picker to Settings tab.

---

## Feature 2: Tasks Tab

### Tab Addition
- New `ChildView.tasks` case added to the segmented picker in `TBPopoverView`.
- Tab order: **Tasks**, Intervals, Settings, Controls, Sounds.
- New `TasksView.swift` in `Views/`.

### Task List
- Grouped by project. Project name as section header (bold, non-tappable).
- Tasks as simple tappable rows underneath.
- Only active (non-completed) tasks shown (Todoist API returns active by default).
- Selected task gets a checkmark or highlight.
- Tapping a different task switches selection immediately.
- Tapping the currently selected task deselects it.

### Refresh
- Refresh button (arrow.clockwise) in top-right of Tasks tab.
- Fetches projects + tasks in parallel, rebuilds grouped list.
- Show inline loading indicator during fetch.
- On error: show brief error text below refresh button, keep stale data visible.

### Data Flow
- `TodoistService` class — handles all API calls, returns Swift structs.
- `TodoistTask` struct: `id: String`, `content: String`, `projectId: String`.
- `TodoistProject` struct: `id: String`, `name: String`.
- Fetched data held in memory (no caching to disk). Refresh on tab open if stale (>5 min) or on manual refresh.
- Selected task ID + name stored in `@AppStorage` for persistence across restarts.

---

## Feature 3: Task Bar in Main Popover

### Layout
- New row above the Start/Stop button row in `TBPopoverView`.
- When task selected: `"Buy Milk"` + `"🍅 3"` badge. Task name truncated with ellipsis if too long.
- When no task selected: `"Select a task..."` in secondary/gray text.
- Entire row is tappable — switches segmented picker to Tasks tab.

### Pomodoro Count Badge
- Format: `🍅 N` next to task name.
- Count sourced from persisted dictionary (see Feature 5).
- Only shown when count > 0.

---

## Feature 4: Pomodoro Logging

### Trigger
- When a **work interval completes** (`onIntervalCompleted` in `TimerStateMachine`) and a Todoist task is selected.
- Fires before any auto-transition or user-choice pause logic.

### Comment Format
```
🍅 Pomodoro #3 completed (25 min)
```
- `#N` = pomodoro count for this task (after increment).
- `25 min` = actual work interval length from current preset.

### API Call
- `POST /rest/v2/comments` with body: `{ "task_id": "<id>", "content": "<message>" }`.
- On failure: retry once after 2 seconds. If second attempt fails, silently drop (log to TBLogger).
- Non-blocking — fires on background queue, never blocks timer state transitions.

### Increment
- Pomodoro count for the selected task incremented by 1 in the persisted dictionary (Feature 5) at the same time the comment is posted.

---

## Feature 5: Session Tracking

### Persistence
- `@AppStorage("todoistPomodoroCountsV1")` — JSON-encoded `[String: Int]` mapping Todoist task ID to pomodoro count.
- Updated on every work interval completion for the selected task.
- Restored on app launch — if a task is still selected, its count is immediately visible.

### Task Switching
- Switching tasks does not reset the old task's count. User might return to it.
- New task's count loaded from dictionary (0 if never worked on).

### Reset
- "Reset count" button in Tasks tab, visible when a task is selected and count > 0.
- Resets only the currently selected task's count to 0.
- Removes the entry from the dictionary.

---

## Feature 6: Menu Bar Task Name

### Display
- When timer is running and a task is selected, append task name to the status bar text.
- Format: `"23:45 Buy Milk"` (space-separated after the time).
- Task name truncated to ~20 characters with ellipsis if longer.

### Toggle
- New setting in Settings tab (Todoist section): "Show task in menu bar" toggle.
- `@AppStorage("showTaskInMenuBar")`, default: `true`.
- When off, menu bar shows only the time as it does today.

### Implementation
- Modify `updateStatusBar()` in `TimerDisplay.swift` to append task name when conditions met (timer running + task selected + toggle on).

---

## New Files

| File | Purpose |
|------|---------|
| `TomoBar/Todoist/TodoistService.swift` | API client — projects, tasks, comments |
| `TomoBar/Todoist/TodoistModels.swift` | TodoistTask, TodoistProject structs |
| `TomoBar/Todoist/KeychainHelper.swift` | Keychain read/write/delete for API token |
| `TomoBar/Todoist/TodoistManager.swift` | Orchestrator — selected task, pomodoro counts, logging |
| `TomoBar/Views/TasksView.swift` | Tasks tab UI |

## Modified Files

| File | Change |
|------|--------|
| `TomoBar.entitlements` | Add `com.apple.security.network.client` |
| `View.swift` | Add Tasks tab to picker, task bar above controls |
| `Views/SettingsView.swift` | Todoist section (token, verify, menu bar toggle) |
| `Timer/TimerStateMachine.swift` | Call TodoistManager on work interval completion |
| `Timer/TimerDisplay.swift` | Append task name to status bar |
| `Timer.swift` | Add TodoistManager as dependency |
| `Views/ViewComponents.swift` | Add Tasks case to ChildView enum |

## Out of Scope (v1)

- OAuth flow
- Task completion from TomoBar (check off tasks)
- Creating new tasks
- Search/filter in task list
- Due date display
- Offline queue for failed comments
- Syncing pomodoro counts with Todoist labels/metadata
