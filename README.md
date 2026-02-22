# plasma-taskmanager-fullheight-launchers

A patch for the KDE Plasma 6 **Icons-and-Text Task Manager** widget
(`org.kde.plasma.taskmanager`) that makes pinned launcher icons render as
**full-height squares** spanning all rows, while open application tasks
continue to use the normal multi-row layout.

```
┌──────────────────────────────────────────────────────────┐
│ [Firefox] [Terminal] │ Dolphin     │ Kate                │
│                      ├─────────────┼─────────────────────┤
│  launchers (40×40)   │ Kate (2)    │                     │
└──────────────────────────────────────────────────────────┘
  ↑ rowSpan=2 squares    ↑ normal 2-row task layout
```

Tested on **Fedora 42 Asahi Remix (aarch64)**, plasma-desktop 6.6.0, Qt 6.10.2,
with a 40 px horizontal panel and `maxStripes = 2`.

---

## Why this is needed

The upstream task manager places launchers in the same grid cells as window
tasks, so with `maxStripes = 2` a launcher renders as a squished half-height
icon occupying only one row. This patch teaches the grid that launchers are
full-panel-height columns while tasks continue to occupy one row each.

---

## How it works

### The core problem

The task list is a Qt `GridLayout`. Each item is a `Task` delegate. With
`maxStripes = 2` every item gets one row, so launchers are only 20 px tall on
a 40 px panel.

The patch assigns `Layout.rowSpan = stripeCount` to launcher items so they
span all rows, and corrects the downstream layout calculations that break when
item widths are no longer uniform.

### Changes (3 QML files)

#### `qml/Task.qml`

- **`isFullHeightLauncher` property** — `true` when the task is a pinned
  launcher on a non-vertical, non-icons-only, non-popup panel. This is the
  single flag that gates every other change.

- **`Layout.rowSpan`** — set to `taskList.stripeCount` for full-height
  launchers so they occupy all rows in the grid.

- **`Layout.fillWidth: false`** — launchers become fixed-width columns;
  regular tasks keep `fillWidth: true` and share the remaining space.

- **`Layout.preferredWidth/Height`** — set to `tasksRoot.height` (the panel
  height) for launchers, giving them an explicit square size.

- **`Layout.maximumWidth`** — `tasksRoot.height` for launchers,
  `preferredMaxWidth()` for tasks. Without this Qt can widen launchers to fill
  the grid column.

- **`Layout.maximumHeight`** — for tasks, capped to
  `tasksRoot.height / stripeCount` so Qt's GridLayout cannot over-expand a
  task into an empty second row when only one window is open.

- **Frame `topMargin`/`bottomMargin`** — the upstream code adds a small icon
  inset on multi-row panels. Launchers are excluded from this inset so their
  icon fills the full panel height.

- **`iconBox` standalone-state width** — when the label is hidden (icon-only
  mode) the icon size is derived from `task.height` instead of
  `taskList.minimumWidth` for full-height launchers, so the icon fills the
  square rather than being sized to the narrowest task in the list.

#### `qml/TaskList.qml`

- **`fullHeightLauncherCount` property** — counts grid children that have
  `isFullHeightLauncher === true`. Used by both `orthogonalCount` and
  `main.qml`.

- **`stripeCount` override** — the upstream formula picks any first child as
  the reference for `stripeSizeLimit`. With full-height launchers present that
  child has a larger `implicitHeight`, which reduces `stripeCount` to 1.
  The patch finds the first *non*-launcher child as the reference, falling back
  to any Task child if all items are launchers.

- **`orthogonalCount` override** — the upstream formula divides all items by
  `stripeCount`, but full-height launchers each occupy exactly one column
  regardless of how many rows there are. The new formula is:
  `fullHeightLauncherCount + ceil(nonLauncherCount / stripeCount)`.

#### `qml/main.qml`

- **`TaskList.Layout.maximumWidth` override** — the upstream formula computes
  `totalMaxWidth / widthOccupation`, which assumes all items share the same
  `maximumWidth`. With mixed columns (launchers at 40 px, tasks at
  `preferredMaxWidth` ≈ 310 px) this over-estimates the total width and creates
  a visual gap at the right edge of the task list. When full-height launchers
  are present the patch uses the exact formula:
  `launcherCols × panelHeight + taskCols × preferredMaxWidth()`.

---

## Installation

### Requirements

- Fedora 41+ (or any distro with KF6 and plasma-desktop 6.6.x packages)
- `git`, `cmake`, `gcc-c++`
- plasma-desktop **6.6.0** (the patch is against tag `v6.6.0`; other versions
  may need adjustments)

### Build and install

```bash
git clone <this-repo> plasma-taskmanager-fullheight-launchers
cd plasma-taskmanager-fullheight-launchers
./build-and-install.sh
```

The script will:

1. Install build dependencies via `dnf` (if available).
2. Sparse-clone `plasma-desktop` at tag `v6.6.0` into `/tmp/plasma-desktop-upstream-src`.
3. Assemble a build tree with the upstream C++ sources and our patched QML files.
4. Build a modified `org.kde.plasma.taskmanager.so`.
5. Install it to `~/.local/lib64/qt6/plugins/plasma/applets/` (or `lib/` on
   non-lib64 systems).
6. Append `QT_PLUGIN_PATH` to `~/.config/plasma-workspace/env/env.sh` so
   plasmashell loads the local `.so` before the system one.

Then restart plasmashell to activate:

```bash
kquitapp6 plasmashell && plasmashell --replace &
```

Or log out and back in.

### Clean rebuild

```bash
./build-and-install.sh --clean
```

---

## How the deployment override works

The `.so` built here is placed in `~/.local/…/plasma/applets/`. Plasmashell
discovers plugins via `QT_PLUGIN_PATH`; by prepending the local directory it
loads our `.so` before the system copy at `/usr/lib64/qt6/plugins/plasma/applets/`.

The QML sources are AOT-compiled into the `.so` (via Qt's QRC embedding and
`qmlcachegen`). A plain filesystem override via `QML_IMPORT_PATH` does not work
because the module contains a `prefer` directive that points back to its
embedded QRC resources. The only reliable override is to ship a complete
replacement `.so`.

---

## Repository layout

```
CMakeLists.txt          Standalone build file (no full plasma-desktop tree needed)
build-and-install.sh    Fetch deps, build, deploy, configure env
qml/
  Task.qml              Patched — full-height launcher Layout properties
  TaskList.qml          Patched — stripeCount / orthogonalCount / fullHeightLauncherCount
  main.qml              Patched — TaskList.Layout.maximumWidth fix
```

The repo contains only the three modified files plus the build infrastructure.
All other source files (`backend.cpp`, remaining QML, etc.) are fetched from
upstream at build time.

### Git history

| Commit | Description |
|--------|-------------|
| `baseline` | Verbatim upstream v6.6.0 copies of the three QML files + CMakeLists |
| `patch` | Our modifications + `build-and-install.sh` |

This makes `git diff baseline..HEAD -- qml/` a clean, readable diff of exactly
what changed.

---

## Caveats

- **Plasma version** — the patch targets plasma-desktop **6.6.0**. Upstream
  QML changes between releases may require re-diffing.
- **Vertical panels** — `isFullHeightLauncher` is `false` on vertical panels;
  they are unaffected.
- **Icons-only task manager** — also unaffected (`iconsOnly` guard).
- **`forceStripes = true`** — the patch preserves this config option; the
  stripe-count capping logic does not override it.
