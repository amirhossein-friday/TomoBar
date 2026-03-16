# Todoist Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use subagent-driven-development to implement this plan task-by-task.

**Goal:** Add Todoist integration to TomoBar — task picker, auto-log pomodoros as comments, session tracking, menu bar task name.

**Spec:** `.friday/specs/todoist-integration.md` (Extremely important! MUST READ)

**Architecture:** New `Todoist/` module with 4 files (models, keychain, API service, manager). Manager is `ObservableObject`, owned by `TBTimer`, passed to views via `@EnvironmentObject`. Hooks into `onIntervalCompleted` in the state machine for auto-logging. UI: new Tasks tab + task bar in main popover + Todoist section in Settings.

**Tech Stack:** Swift 5.9+, SwiftUI, URLSession, Security framework (Keychain), Combine (@Published), @AppStorage (UserDefaults)

**Branch:** `feat/todoist-integration`

**Acceptance Criteria:**
- Build succeeds: `xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build` passes with zero errors
- KeychainHelper correctly saves/loads/deletes tokens via Security framework
- TodoistService fetches projects and tasks from Todoist REST API v2 with valid auth
- TodoistService posts comments to tasks via POST /rest/v2/comments
- TasksView displays tasks grouped by project with correct selection behavior
- SettingsView shows Todoist section with token input, verify button, status indicator, disconnect
- TBPopoverView shows task bar above controls with selected task name and pomodoro count
- Timer completion triggers comment posting when task is selected (non-blocking)
- Pomodoro counts persist across app restarts via @AppStorage
- Menu bar shows task name when timer running + task selected + toggle on
- Tasks tab shows empty state with "Go to Settings" when no token configured
- Network entitlement added to TomoBar.entitlements
- visual: Tasks tab integrates seamlessly with existing tab bar style
- visual: Task bar in main popover is visually consistent with existing controls layout
- visual: Settings Todoist section matches the visual style of existing settings sections
- visual: Menu bar text with task name is readable and properly truncated

---

## Important Notes for Implementer

**No test target exists.** This project has no test bundle. TDD verification = compile + build succeeds + manual inspection. Every task ends with a build step to verify. The "test" is the build passing.

**Xcode project management:** New files must be added to the Xcode project (`TomoBar.xcodeproj/project.pbxproj`). Use the `pbxproj` Python package (`pip install pbxproj`) to add file references and build phase entries programmatically. The workflow for each new file:

```bash
# Install once
pip install pbxproj

# Add a file to the project (creates file ref + build source entry)
python3 -c "
from pbxproj import XcodeProject
project = XcodeProject.load('TomoBar.xcodeproj/project.pbxproj')
project.add_file('TomoBar/Todoist/ExampleFile.swift', parent=project.get_or_create_group('Todoist', parent=project.get_or_create_group('TomoBar')))
project.save()
"
```

If `pbxproj` is unavailable, fall back to opening Xcode (`open TomoBar.xcodeproj`), creating the `Todoist` group in the sidebar, and adding files via File > Add Files. Then close Xcode before continuing CLI work.

New Todoist group + 5 Swift files need pbxproj entries.

**SwiftUI reactivity:** `TodoistManager` is an `ObservableObject` owned by `TBTimer`. Since views observe `TBTimer` via `@EnvironmentObject`, changes to `TodoistManager.@Published` properties will NOT automatically trigger `TBTimer.objectWillChange`. Solution: in `TBTimer.init()`, forward `todoist.objectWillChange` to `self.objectWillChange` using Combine:

```swift
private var cancellables = Set<AnyCancellable>()
// In init():
todoist.objectWillChange.sink { [weak self] _ in
    self?.objectWillChange.send()
}.store(in: &cancellables)
```

This ensures that any view observing `timer` via `@EnvironmentObject` re-renders when Todoist state changes.

**Threading:** `TodoistManager` must be marked `@MainActor` to ensure all `@Published` property mutations happen on the main thread. All async work (API calls) runs in detached tasks or via `URLSession` (which returns to the caller's context), with results assigned back on MainActor.

**Existing patterns to follow:**
- `TBTimer` owns all subsystems (`player`, `notify`, `dnd`) → also owns `todoist` (TodoistManager)
- `@AppStorage` on `TBTimer` for all persisted settings
- Views receive `timer` via `@EnvironmentObject`
- `ChildView` enum in `View.swift:3-5` controls tabs
- Segmented picker in `View.swift:121-133`, GroupBox switch in `View.swift:135-146`
- Settings sections in `SettingsView.swift` are raw VStack children (no `Form` or `Section` — just HStack rows)
- Logging via global `logger.append(event:)` using `TBLogger` (`Log.swift`)

**Build command:**
```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected success output: `** BUILD SUCCEEDED **`

---

## Task 1: Create Feature Branch + Add Network Entitlement

**Files:**
- Modify: `TomoBar/TomoBar.entitlements:15-21`

**Step 1: Create feature branch**

```bash
git checkout -b feat/todoist-integration
```

**Step 2: Add network client entitlement**

In `TomoBar/TomoBar.entitlements`, add `com.apple.security.network.client` key with `<true/>` value. Insert before the closing `</dict>` tag (line 21) — after the mach-lookup exception block (line 20).

The entitlements file is XML plist format. Add the key-value pair inside the top-level `<dict>` element, at the end before `</dict>`.

**Step 3: Build to verify**

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add TomoBar/TomoBar.entitlements
git commit -m "build: add network client entitlement for Todoist API"
```

---

## Task 2: Create TodoistModels

**Files:**
- Create: `TomoBar/Todoist/TodoistModels.swift`

**Step 1: Create the Todoist directory and models file**

Create `TomoBar/Todoist/` directory. Create `TodoistModels.swift` with:

- `TodoistProject` struct: `id: String`, `name: String`. Conforming to `Codable`, `Identifiable`.
- `TodoistTask` struct: `id: String`, `content: String`, `projectId: String`. Conforming to `Codable`, `Identifiable`. Note: Todoist API uses `project_id` in JSON — use `CodingKeys` to map `projectId` to `project_id`.

These are simple Codable data transfer objects for the Todoist REST API v2 responses.

**Step 2: Add file to Xcode project**

The new file must be registered in `TomoBar.xcodeproj/project.pbxproj`. Use the `pbxproj` Python package (see "Important Notes for Implementer" above) to create a `Todoist` group under `TomoBar` and add the file. Alternatively, open Xcode and add files via the GUI. Every new `.swift` file in this plan needs the same pbxproj treatment — won't be repeated in detail after this task.

**Step 3: Build to verify**

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add TomoBar/Todoist/TodoistModels.swift TomoBar.xcodeproj/project.pbxproj
git commit -m "feat(todoist): add TodoistProject and TodoistTask models"
```

---

## Task 3: Create KeychainHelper

**Files:**
- Create: `TomoBar/Todoist/KeychainHelper.swift`

**Step 1: Implement KeychainHelper**

Create `KeychainHelper.swift` as a `struct` with three static methods:

- `save(token: String)` — Uses `SecItemAdd`. Query dict: `kSecClass: kSecClassGenericPassword`, `kSecAttrService: "com.tomobar.todoist-token"`, `kSecValueData: token.data(using: .utf8)`. If item already exists (`errSecDuplicateItem`), call `SecItemUpdate` to overwrite.
- `load() -> String?` — Uses `SecItemCopyMatching`. Same service key. Returns `kSecReturnData: true`, `kSecMatchLimit: kSecMatchLimitOne`. Convert result `Data` to `String`.
- `delete()` — Uses `SecItemDelete`. Same service key query.

Import `Security` framework (already linked by default in macOS apps).

**Step 2: Add file to Xcode project**

Add to the Todoist group in `project.pbxproj` (same process as Task 2).

**Step 3: Build to verify**

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add TomoBar/Todoist/KeychainHelper.swift TomoBar.xcodeproj/project.pbxproj
git commit -m "feat(todoist): add KeychainHelper for API token storage"
```

---

## Task 4: Create TodoistService (API Client)

**Files:**
- Create: `TomoBar/Todoist/TodoistService.swift`

**Step 1: Implement TodoistService**

Create `TodoistService` as a `class`. Constructor takes `token: String`. All methods are `async throws`.

Three methods:

- `fetchProjects() async throws -> [TodoistProject]` — `GET https://api.todoist.com/rest/v2/projects`. Header: `Authorization: Bearer <token>`. Decode JSON array of `TodoistProject`.
- `fetchTasks() async throws -> [TodoistTask]` — `GET https://api.todoist.com/rest/v2/tasks`. Same auth header. Decode JSON array of `TodoistTask`.
- `postComment(taskId: String, content: String) async throws` — `POST https://api.todoist.com/rest/v2/comments`. Body: `{"task_id": "<taskId>", "content": "<content>"}`. Set `Content-Type: application/json`. Don't need to decode response — just check for 200 status.

Use `URLSession.shared.data(for:)` (async/await). Throw on non-2xx status codes.

**Step 2: Add file to Xcode project**

Add to the Todoist group in `project.pbxproj`.

**Step 3: Build to verify**

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add TomoBar/Todoist/TodoistService.swift TomoBar.xcodeproj/project.pbxproj
git commit -m "feat(todoist): add TodoistService API client"
```

---

## Task 5: Create TodoistManager (Orchestrator)

**Files:**
- Create: `TomoBar/Todoist/TodoistManager.swift`

**Step 1: Implement TodoistManager**

Create `TodoistManager` as a `@MainActor class: ObservableObject`. This is the orchestrator that ties together token, service, selection, counts, and logging. The `@MainActor` annotation ensures all `@Published` property mutations happen on the main thread — critical for SwiftUI reactivity.

Published properties:
- `@Published var projects: [TodoistProject] = []`
- `@Published var tasks: [TodoistTask] = []`
- `@Published var isLoading = false`
- `@Published var errorMessage: String? = nil`
- `@Published var tokenStatus: TokenStatus = .none` (enum: `none`, `verifying`, `connected`, `invalid`)

AppStorage properties (stored on this object, not TBTimer — keeps Todoist state self-contained):
- `@AppStorage("selectedTodoistTaskId") var selectedTaskId: String = ""`
- `@AppStorage("selectedTodoistTaskName") var selectedTaskName: String = ""`
- `@AppStorage("showTaskInMenuBar") var showTaskInMenuBar: Bool = true`
- `@AppStorage("todoistPomodoroCountsV1") private var countsData: Data = Data()`

Computed properties:
- `var hasToken: Bool` — calls `KeychainHelper.load() != nil`
- `var hasSelectedTask: Bool` — `!selectedTaskId.isEmpty`
- `var pomodoroCountForSelectedTask: Int` — reads from decoded counts dict
- `var tasksByProject: [(project: TodoistProject, tasks: [TodoistTask])]` — groups `tasks` by `projectId`, matches to `projects`, sorted by project name. Tasks without a matching project go under "No Project".

Key methods:
- `func verifyToken(_ token: String)` — Save to Keychain, create `TodoistService`, call `fetchProjects()`. On success: set `tokenStatus = .connected`. On failure: delete token, set `tokenStatus = .invalid`.
- `func disconnect()` — Delete token from Keychain, clear `selectedTaskId`, `selectedTaskName`, `projects`, `tasks`, set `tokenStatus = .none`.
- `func refreshTasks()` — Guard `hasToken`. Set `isLoading = true`. Load token from Keychain, create service, fetch projects + tasks concurrently (`async let`). Store results. Set `isLoading = false`. On error: set `errorMessage`.
- `func selectTask(_ task: TodoistTask)` — Set `selectedTaskId = task.id`, `selectedTaskName = task.content`.
- `func deselectTask()` — Clear `selectedTaskId` and `selectedTaskName`.
- `func incrementPomodoroCount() -> Int` — Decode counts dict, increment `counts[selectedTaskId]`, re-encode, return new count.
- `func resetPomodoroCount()` — Remove `selectedTaskId` entry from counts dict, re-encode.
- `func logPomodoro(workMinutes: Int)` — Guard `hasSelectedTask` and `hasToken`. Call `incrementPomodoroCount()` to get new count. Format comment: `"🍅 Pomodoro #\(count) completed (\(workMinutes) min)"`. Fire-and-forget `Task { ... }`: call `service.postComment(...)`. On failure: wait 2s, retry once. On second failure: log to `TBLogger` and silently drop.

The `countsData` AppStorage property stores a JSON-encoded `[String: Int]` dictionary. Provide private helpers `decodeCounts() -> [String: Int]` and `encodeCounts(_:)` to read/write.

Additional methods:
- `func refreshIfStale()` — Guard `hasToken`. If `lastFetchTime` is nil or more than 5 minutes ago, call `refreshTasks()`. Otherwise no-op. This is called from `TasksView.onAppear`.

`refreshTasks()` should also be triggered when token is verified. Store `lastFetchTime: Date?` privately. Updated on successful fetch.

Initialization:
- In `init()`, check if a token exists in Keychain via `KeychainHelper.load()`. If so, set `tokenStatus = .connected` (trust saved token — don't verify on every launch to avoid network dependency at startup). If `selectedTaskId` is non-empty and token exists, the task bar will automatically show persisted task name and count via `@AppStorage`.

**Step 2: Add file to Xcode project**

Add to the Todoist group in `project.pbxproj`.

**Step 3: Build to verify**

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add TomoBar/Todoist/TodoistManager.swift TomoBar.xcodeproj/project.pbxproj
git commit -m "feat(todoist): add TodoistManager orchestrator"
```

---

## Task 6: Wire TodoistManager into TBTimer

**Files:**
- Modify: `TomoBar/Timer.swift:59-65` (add todoist property)
- Modify: `TomoBar/Timer/TimerStateMachine.swift:336-341` (hook into onIntervalCompleted)

**Step 1: Add TodoistManager to TBTimer**

In `Timer.swift`, after line 64 (`public var dnd = TBDoNotDisturb()`), add:

```swift
public let todoist = TodoistManager()
```

This follows the same pattern as `player`, `notify`, `dnd` — subsystems owned by `TBTimer`.

Also add a `private var cancellables = Set<AnyCancellable>()` property to `TBTimer` (import `Combine` at top if not already imported). In `init()`, after `setupStateMachine()`, add the Combine forwarding so views observing `TBTimer` re-render when Todoist state changes:

```swift
todoist.objectWillChange.sink { [weak self] _ in
    self?.objectWillChange.send()
}.store(in: &cancellables)
```

**Step 2: Hook into work interval completion**

In `TimerStateMachine.swift`, in `onIntervalCompleted(context:)` method (line 336-353), after the `player.playDing()` call (line 340) and still inside the `if ctx.fromState == .work` block, add the Todoist logging call:

```swift
todoist.logPomodoro(workMinutes: currentPresetInstance.workIntervalLength)
```

This is non-blocking because `logPomodoro()` internally uses `Task { ... }` to fire the API call on a background queue. It must come after `player.playDing()` and before any auto-transition/user-choice logic.

**Step 3: Build to verify**

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add TomoBar/Timer.swift TomoBar/Timer/TimerStateMachine.swift
git commit -m "feat(todoist): wire TodoistManager into TBTimer and state machine"
```

---

## Task 7: Add Tasks Tab to ChildView Enum and Picker

**Files:**
- Modify: `TomoBar/View.swift:3-5` (ChildView enum)
- Modify: `TomoBar/View.swift:121-133` (Picker)
- Modify: `TomoBar/View.swift:135-146` (GroupBox switch)

**Step 1: Add `.tasks` case to ChildView enum**

In `View.swift`, line 3-5. Add `tasks` as the first case:

```swift
enum ChildView {
    case tasks, intervals, settings, shortcuts, sounds
}
```

**Step 2: Add Tasks tab to the Picker**

In the `Picker` block (lines 121-133), add a Tasks entry as the **first** item (before Intervals):

```swift
Text(NSLocalizedString("View.tasks.label",
                       comment: "Tasks label")).tag(ChildView.tasks)
```

Note: No localization file exists yet for "View.tasks.label" — use `NSLocalizedString` anyway for consistency. The key will fall back to the key itself. For now, hardcode in the `Localizable.strings` if it exists, or just use `Text("Tasks")` directly if the project doesn't have localization files for English. Check the project's localization setup.

**Step 3: Add TasksView case to GroupBox switch**

In the GroupBox switch (lines 135-146), add a case for `.tasks`:

```swift
case .tasks:
    TasksView().environmentObject(timer)
```

This will cause a build error until Task 8 creates `TasksView.swift`. That's expected — skip build verification here and it will be verified in Task 8.

**Step 4: Commit (no build yet — depends on Task 8)**

Do NOT commit yet. Continue to Task 8 first. Task 7 and 8 should be committed together since they have a compile-time dependency.

---

## Task 8: Create TasksView

**Files:**
- Create: `TomoBar/Views/TasksView.swift`

**Step 1: Implement TasksView**

Create `TasksView.swift` in `Views/`. Structure:

```swift
struct TasksView: View {
    @EnvironmentObject var timer: TBTimer

    var body: some View {
        // ...
    }
}
```

**Layout logic:**

1. **No token state:** When `!timer.todoist.hasToken`, show:
   - Text: "Connect Todoist to get started" (centered, secondary color)
   - Button: "Go to Settings" — sets a binding or calls a closure to switch the parent's `activeChildView` to `.settings`

   Problem: `activeChildView` is `@State` in `TBPopoverView`, not accessible from child views. Solution: pass a `Binding<ChildView>` down to `TasksView`, or use a shared `@Published` property. Simplest: change `activeChildView` from `@State` in `TBPopoverView` to a `@Published` on `TBTimer` (or keep `@State` and pass `$activeChildView` as a binding to `TasksView`). **Recommended:** Pass `$activeChildView` as a `Binding<ChildView>` parameter to `TasksView` constructor.

2. **Has token, task list:** When `timer.todoist.hasToken`:
   - **Top bar:** HStack with selected task info + refresh button (SF Symbol `arrow.clockwise`).
   - **Reset count button:** If `timer.todoist.hasSelectedTask && timer.todoist.pomodoroCountForSelectedTask > 0`, show a "Reset count" button.
   - **Loading state:** If `timer.todoist.isLoading`, show `ProgressView()`.
   - **Error state:** If `timer.todoist.errorMessage != nil`, show error text in `.secondary` color.
   - **Task list:** `ScrollView` with `VStack(alignment: .leading)`. Iterate over `timer.todoist.tasksByProject`. For each group:
     - Project name as bold header text (non-tappable)
     - Tasks as `Button` rows. Each row shows task content text. Selected task has a checkmark (Image(systemName: "checkmark")) on the trailing edge.
     - Tapping a task: if it's already selected, call `timer.todoist.deselectTask()`. Otherwise call `timer.todoist.selectTask(task)`.
   - **Auto-refresh:** `.onAppear { timer.todoist.refreshIfStale() }` — refresh if >5 min since last fetch.

Keep the view under ~150 LOC. The `TasksView` receives `Binding<ChildView>` for tab switching.

Update `View.swift` GroupBox to pass the binding:
```swift
case .tasks:
    TasksView(activeTab: $activeChildView).environmentObject(timer)
```

**Step 2: Add file to Xcode project**

Add `TasksView.swift` to the Views group in `project.pbxproj`.

**Step 3: Build to verify** (this also validates Task 7)

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit** (Tasks 7 + 8 together)

```bash
git add TomoBar/View.swift TomoBar/Views/TasksView.swift TomoBar.xcodeproj/project.pbxproj
git commit -m "feat(todoist): add Tasks tab with project-grouped task list"
```

---

## Task 9: Add Task Bar to Main Popover

**Files:**
- Modify: `TomoBar/View.swift` (insert task bar above button row)

**Step 1: Add task bar view**

In `TBPopoverView`'s `body` (View.swift), insert a new view element as the **first child of the `VStack(alignment: .leading, spacing: 8)`**, before the `HStack(alignment: .center, spacing: 4)` button row. (Note: line numbers will have shifted from Tasks 7-8 edits — search for the `HStack(alignment: .center, spacing: 4)` to find the button row.)

The task bar is a tappable `HStack`:
- **When task selected:** Left side: task name text (`.lineLimit(1)`, truncated). Right side: `"🍅 N"` text (only if count > 0). Use `timer.todoist.selectedTaskName` and `timer.todoist.pomodoroCountForSelectedTask`.
- **When no task selected:** `"Select a task..."` in `.secondary` foreground color.
- **Tap action:** Set `activeChildView = .tasks`.
- **Styling:** `.padding(.vertical, 4)`, subtle styling to match existing UI. Use `.contentShape(Rectangle())` to make entire row tappable.

Keep it compact — this should be a single row, not tall.

**Step 2: Build to verify**

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add TomoBar/View.swift
git commit -m "feat(todoist): add task bar above timer controls in popover"
```

---

## Task 10: Add Todoist Section to SettingsView

**Files:**
- Modify: `TomoBar/Views/SettingsView.swift:123-124` (insert before final Spacer)

**Step 1: Add Todoist settings section**

In `SettingsView.swift`, insert a new section after the language picker (after line 123) and before `Spacer().frame(minHeight: 0)` (line 124).

Add a visual separator first (e.g., `Divider().padding(.vertical, 4)`), then the Todoist section.

The section needs local `@State` for the token input field:
- `@State private var tokenInput: String = ""`

Layout:

1. **Section header:** Bold text "Todoist" (left-aligned).

2. **When not connected** (`timer.todoist.tokenStatus != .connected`):
   - `SecureField("API Token", text: $tokenInput)` — text field for entering token.
   - "Verify" button — calls `timer.todoist.verifyToken(tokenInput)`. Disabled when `tokenInput.isEmpty` or `tokenStatus == .verifying`.
   - Status text below: show `"Verifying..."` (during verify), `"Invalid token"` (on failure, red), nothing (when `.none`).

3. **When connected** (`timer.todoist.tokenStatus == .connected`):
   - Status: `"Connected"` text in green.
   - "Disconnect" button — calls `timer.todoist.disconnect()`, clears `tokenInput`.
   - Toggle: "Show task in menu bar" — bound to `$timer.todoist.showTaskInMenuBar`. Use `.toggleStyle(.switch)` to match existing toggles.

Follow the existing visual pattern: `HStack` with label `.frameInfinityLeading()` and control on the right. The `.frameInfinityLeading()` helper is defined in `ViewComponents.swift`.

**Step 2: Build to verify**

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add TomoBar/Views/SettingsView.swift
git commit -m "feat(todoist): add Todoist section to Settings (token, verify, disconnect)"
```

---

## Task 11: Add Task Name to Menu Bar

**Files:**
- Modify: `TomoBar/Timer/TimerDisplay.swift:33-52` (modify updateStatusBar)

**Step 1: Modify updateStatusBar()**

In `TimerDisplay.swift`, modify `updateStatusBar()` to append the task name when conditions are met.

Current code sets title to `timeLeftString` or `nil`. Modify the `.running` and `.always` cases to build a combined string when:
- `todoist.hasSelectedTask == true`
- `todoist.showTaskInMenuBar == true`
- Timer is running (not nil, not paused)

The task name should be truncated to ~20 characters. Create a local helper or inline:
```swift
let taskSuffix: String = {
    guard todoist.hasSelectedTask && todoist.showTaskInMenuBar else { return "" }
    let name = todoist.selectedTaskName
    let truncated = name.count > 20 ? String(name.prefix(20)) + "..." : name
    return " " + truncated
}()
```

Then in the `.running` case: `setTitle(timeLeftString + taskSuffix)`.
In the `.always` case: only append when timer is actually running (`timer != nil && !paused`), otherwise just show `timeLeftString`.

**Step 2: Build to verify**

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add TomoBar/Timer/TimerDisplay.swift
git commit -m "feat(todoist): show task name in menu bar when timer running"
```

---

## Task 12: Final Build Verification + Cleanup

**Step 1: Clean build**

```bash
xcodebuild -project TomoBar.xcodeproj -scheme TomoBar clean build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **` with zero errors and zero warnings related to Todoist code.

**Step 2: Verify all new files are tracked**

```bash
git status
```

All Todoist files should be committed. No untracked files except `.friday/` plan files.

**Step 3: Review all changes**

```bash
git log --oneline feat/todoist-integration --not main
```

Expected commits (newest first):
1. `feat(todoist): show task name in menu bar when timer running`
2. `feat(todoist): add Todoist section to Settings (token, verify, disconnect)`
3. `feat(todoist): add task bar above timer controls in popover`
4. `feat(todoist): add Tasks tab with project-grouped task list`
5. `feat(todoist): wire TodoistManager into TBTimer and state machine`
6. `feat(todoist): add TodoistManager orchestrator`
7. `feat(todoist): add TodoistService API client`
8. `feat(todoist): add KeychainHelper for API token storage`
9. `feat(todoist): add TodoistProject and TodoistTask models`
10. `build: add network client entitlement for Todoist API`

**Step 4: Manual smoke test checklist** (for human verification)

- [ ] Launch app — menu bar icon appears, no crash
- [ ] Open popover — task bar shows "Select a task..." above controls
- [ ] Go to Settings — Todoist section visible with token input
- [ ] Enter API token, click Verify — status changes to "Connected"
- [ ] Switch to Tasks tab — tasks load, grouped by project
- [ ] Select a task — checkmark appears, task bar updates with name
- [ ] Start a work interval — menu bar shows time + task name
- [ ] Complete a work interval — comment posted to Todoist task
- [ ] Relaunch app — selected task + count persists
- [ ] Disconnect in Settings — token cleared, Tasks tab shows empty state

**Step 5: Final commit (if any cleanup needed)**

```bash
git add -A && git commit -m "chore: final cleanup for todoist integration"
```

---

## File Reference Summary

### New Files (5)
| File | Task | Purpose |
|------|------|---------|
| `TomoBar/Todoist/TodoistModels.swift` | 2 | TodoistProject, TodoistTask structs |
| `TomoBar/Todoist/KeychainHelper.swift` | 3 | Keychain CRUD for API token |
| `TomoBar/Todoist/TodoistService.swift` | 4 | URLSession API client |
| `TomoBar/Todoist/TodoistManager.swift` | 5 | Orchestrator (state, counts, logging, init) |
| `TomoBar/Views/TasksView.swift` | 8 | Tasks tab UI |

### Modified Files (6)
| File | Task | Change |
|------|------|--------|
| `TomoBar/TomoBar.entitlements` | 1 | Add `com.apple.security.network.client` |
| `TomoBar/View.swift` | 7, 8, 9 | ChildView enum, picker, GroupBox, task bar |
| `TomoBar/Timer.swift` | 6 | Add `todoist` property |
| `TomoBar/Timer/TimerStateMachine.swift` | 6 | Hook `logPomodoro()` into `onIntervalCompleted` |
| `TomoBar/Timer/TimerDisplay.swift` | 11 | Append task name to status bar |
| `TomoBar/Views/SettingsView.swift` | 10 | Todoist section (token, verify, toggle) |

### Also Modified
| File | Task | Change |
|------|------|--------|
| `TomoBar.xcodeproj/project.pbxproj` | 2-5, 8 | New file references + build phases |

---

## Task Dependency Graph

```
Task 1 (entitlement)
   ↓
Task 2 (models) ───────────┐
   │                        │
Task 3 (keychain) ─────────┤  (2, 3, 4 have no code deps — any order OK)
   │                        │
Task 4 (service) ──────────┘
   ↓
Task 5 (manager + init)
   ↓
Task 6 (wire into TBTimer + Combine forwarding)
   ↓
Task 7 (ChildView enum + picker) ──→ Task 8 (TasksView) [commit together]
   ↓
Task 9 (task bar in popover)
   ↓
Task 10 (settings UI)
   ↓
Task 11 (menu bar task name)
   ↓
Task 12 (final verification)
```

Tasks 2, 3, 4 have no code dependencies between each other and can be done in any order, but all must complete before Task 5. Tasks 7+8 must be committed together. All other tasks are sequential.
