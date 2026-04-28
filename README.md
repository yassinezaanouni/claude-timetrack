# Claude Time Track

A macOS menu bar app that shows how much time you've spent in each project,
tracked automatically from Claude Code's session files in `~/.claude/projects/`.

No instrumentation, no extension to install. If you use Claude Code, the data
is already on disk.

## Screenshots

| Light Mode | Dark Mode |
|---|---|
| ![Light mode](screenshots/light-mode.png) | ![Dark mode](screenshots/dark-mode.png) |

## How it works

The app maintains two independent time estimates per project. Flip between
them with the **Claude / Git** toggle in the header.

### Claude mode

Every Claude Code message is logged with a `timestamp` and a `cwd`. The app
parses every session JSONL file under `~/.claude/projects/`, resolves each
event to its git repo root, and groups them by project.

Within each session file, consecutive events are stitched into "sittings".
Any gap longer than the configured idle threshold (default **15 min**) splits
a sitting; the active time of a sitting is the wall-clock span between its
first and last message. Long idle gaps are dropped, so leaving Claude Code
open overnight does not pad your numbers.

### Git mode

For each project root the app runs `git log --no-merges --pretty=format:%aI`
(filtered by your global `user.email` by default) and applies the
[`git-hours`](https://github.com/kimmobrunfeldt/git-hours) heuristic:

- Sort commits by author timestamp.
- For each consecutive pair, if the gap is **≤ 2 h** (configurable), add the
  gap to the total. Otherwise treat it as the boundary of a new coding
  session and add **2 h** instead (configurable).
- The very first commit also gets the first-commit addition, since its
  pre-history is unknown.

Results are cached per repo by `HEAD` SHA so subsequent refreshes are free
when nothing has changed.

The menu bar title shows the total for the selected range — Today / This week
/ All time — refreshed every minute by default.

## Build & install

```bash
./build_app.sh
open ~/Applications/ClaudeTimeTrack.app
```

The script:
1. Compiles a release binary with SwiftPM
2. Assembles `~/Applications/ClaudeTimeTrack.app` with a proper `Info.plist`
   (`LSUIElement=true`, so the app is menu-bar-only)
3. Ad-hoc codesigns the bundle so `SMAppService` will accept it for
   launch-at-login

On first launch the app registers itself for **launch at login** automatically
via `SMAppService.mainApp.register()`. You can toggle this from Settings.

## Features

- **Two data sources** — flip between Claude Code session time and `git-hours`
  commit estimates with one click
- **Three time ranges** — Today, This week, All time, switchable from the header pill
- **Live totals** in the menu bar title, refreshed every minute
- **Stacked breakdown bar** at the top showing every project's share
- **Per-project rows** — palette color, duration with day hint, last-active
  label, and proportion bar. Hover reveals the path plus Reveal-in-Finder,
  Hide, and Drill-in actions
- **Project detail view** — Today / Week / All-time stats, session/commit
  counts, a 14-day sparkline, and the last 20 sittings (Claude mode) or
  commit summary (Git mode)
- **Search** to filter projects by name or path
- **Appearance** — System / Light / Dark
- **Settings** — launch-at-login, Claude idle-gap (1–60 min), refresh interval
  (15–600 s), Git max-gap and first-commit additions (15–480 min), filter by
  your git email, max rows shown, hidden projects
- **Adaptive theme** with a glassy `NSVisualEffectView` background

## Development

```bash
swift build
.build/debug/ClaudeTimeTrack    # logs to stdout
```

Requirements: macOS 14+, Swift 5.10+.

## Project layout

```
Models/      SessionEvent, ProjectUsage (+ GitStats), TimeRange, TrackingSource, Theme
Services/    SessionTracker (JSONL parser + per-file mtime cache),
             GitHistoryAnalyzer (git-hours heuristic + HEAD-based cache),
             GitRootResolver
State/       AppState (@Observable, settings, launch-at-login, refresh timer)
Utilities/   TimeFormat
Views/       ContentView, MainView, HeaderView (+ TimeRangePicker, SourcePicker,
             SearchBar), ProjectListView, ProjectRowView, ProjectDetailView,
             FooterView, SettingsView
```

## Credits

The git-mode estimate uses the algorithm from
[`kimmobrunfeldt/git-hours`](https://github.com/kimmobrunfeldt/git-hours).

## Uninstall

```bash
rm -rf ~/Applications/ClaudeTimeTrack.app
defaults delete com.yassinezaanouni.claudetimetrack
```

Then unregister launch-at-login from System Settings → General → Login Items.

## License

MIT
