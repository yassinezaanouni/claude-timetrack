# Claude Time Track

A macOS menu bar app that shows how much time you've spent in each project — tracked from Claude Code's session files and your git history. No instrumentation, no extension. If you use Claude Code or git, the data is already on disk.

| Light | Dark |
|---|---|
| ![Light mode](screenshots/light-mode.png) | ![Dark mode](screenshots/dark-mode.png) |

## Features

- **Two data sources, side by side** — every project row shows both Claude session time and `git-hours` commit time. Tap either to make it the active view.
- **Three ranges** — Today / Week / All time, with live totals in the menu bar.
- **Stacked breakdown bar** — see at a glance which projects ate your day.
- **Project detail view** — Today / Week / All-time stats, 14-day sparkline, last 20 sittings (Claude) or commit summary (Git).
- **Appearance** — System / Light / Dark.
- **Hands-off** — auto-refresh every minute, launch-at-login, hide projects you don't care about.

## How it works

**Claude mode.** Every Claude Code message has a `timestamp` and a `cwd`. The app parses every JSONL under `~/.claude/projects/`, resolves each event to its git repo root, and stitches consecutive events into sittings. Gaps longer than the idle threshold (default **15 min**) split sittings, so leaving Claude open overnight doesn't pad your numbers.

**Git mode.** For each repo, the app runs `git log --no-merges --pretty=format:%aI` (filtered by your global `user.email`) and applies the [`git-hours`](https://github.com/kimmobrunfeldt/git-hours) heuristic: gaps **≤ 2 h** count as work; longer gaps mark a new session and add a flat **2 h** for the opening commit. Both thresholds are configurable. Cached per repo by `HEAD` SHA.

## Install

```bash
./build_app.sh
open ~/Applications/ClaudeTimeTrack.app
```

The script compiles a release binary, assembles a `.app` bundle (`LSUIElement=true`, menu-bar-only), and ad-hoc codesigns it so `SMAppService` accepts it for launch-at-login. On first launch the app registers itself; toggle from Settings.

## Develop

```bash
swift build
.build/debug/ClaudeTimeTrack    # logs to stdout
```

Requires macOS 14+, Swift 5.10+.

## Uninstall

```bash
rm -rf ~/Applications/ClaudeTimeTrack.app
defaults delete com.yassinezaanouni.claudetimetrack
```

Then unregister launch-at-login from System Settings → General → Login Items.

## Credits

Git-mode estimate uses the algorithm from [`kimmobrunfeldt/git-hours`](https://github.com/kimmobrunfeldt/git-hours).

## License

MIT
