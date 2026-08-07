# Expunge

**The macOS uninstaller that actually removes everything.**

[简体中文](README.zh-CN.md) | **English**

Free, open-source, and thorough. Uninstall any Mac app — and sweep up every trace it left behind: Homebrew formulas, npm/pipx packages, sandbox containers, launch agents, shell config pollution, dotfiles, caches, and more. 16 scanner categories, zero leftovers.

**Everything goes to Trash by default** — undo anytime.

> **System Requirements:** macOS 14 (Sonoma) or later. Intel & Apple Silicon. [Why macOS 14?](#system-requirements)

![Expunge main interface](screenshots/main.png)

---

## Features

### 🧹 Deep Uninstall
Select an app, Expunge finds everything connected to it. Not just the `.app` bundle — dependencies, preferences, caches, logs, containers, and CLI tools installed by package managers. Confirm once, it's all gone.

![Deep uninstall](screenshots/uninstall.png)

### 🔍 Orphan Scanner
Apps you deleted months ago often leave data behind. The orphan scanner reverse-looks: which `~/Library` directories have no living app to claim them? Finds forgotten leftovers you didn't even know existed.

![Orphan scanner](screenshots/orphans.png)

### 🤖 AI Agent ("Ask AI")
Describe what you want in natural language — "uninstall Cursor completely" or "scan all leftovers" — and the built-in AI agent calls the right skills, inspects the results, and drafts a plan. Nothing is removed without your explicit confirmation. Saves corrections across sessions with `/remember`.

![AI Agent](screenshots/agent.png)

### 🖥️ Process Manager
See every background process running on your Mac — node servers, Python scripts, Docker containers, Brew services. Shows memory usage, CPU %, and **listening ports** (e.g. `:3000`, `:8080`). Search by port number to find exactly which process is holding it. Kill with one click.

![Process manager](screenshots/processes.png)

### 🛡️ Safety by Design
- **Trash, never delete.** Everything goes to Trash first. Empty it when you're ready.
- **No shell access.** The AI agent can only call predefined, read-only skills. It can't run arbitrary commands, read arbitrary files, or access the network.
- **Confirmation required.** Every removal action asks for confirmation. No silent deletions.
- **System protection.** Critical system processes and paths are whitelisted and can never be removed.
- **Offline-first.** All processing is local. No data leaves your machine.

---

## Installation

### Download DMG (Recommended)

Download `Expunge-<version>.dmg` and its `.sha256` from [Releases](https://github.com/expunge-mac/expunge-mac-uninstaller/releases). Verify first:

```bash
shasum -a 256 -c Expunge-<version>.dmg.sha256   # Should print OK
```

Open the DMG, drag Expunge to Applications. First launch: **right-click → Open** (required for unsigned apps).

### Build from Source

```bash
git clone https://github.com/expunge-mac/expunge-mac-uninstaller.git
cd expunge-mac-uninstaller
./build_app.sh                       # → /Applications/Expunge.app
open /Applications/Expunge.app
```

To build a DMG for distribution:

```bash
./build_release.sh                   # → dist/Expunge-<version>.dmg + .sha256
```

### CLI Only

```bash
swift build -c release
.build/release/Expunge --scan "WeChat"   # Scan an app
.build/release/Expunge --self-test       # Run self-tests
.build/release/Expunge --skills          # List agent skills
```

---

## How It Works

Expunge scans across 16 categories:

| Category | What It Finds |
|----------|--------------|
| `.app` bundles | Installed applications |
| Homebrew | Formulas, casks, taps |
| npm / pipx | Global packages |
| Sandbox containers | `~/Library/Containers` data |
| Launch agents | `~/Library/LaunchAgents` plists |
| Shell configs | `.zshrc`, `.bashrc`, `.fish` entries |
| Dotfiles | `.cursor`, `.claude`, config dirs |
| Caches | `~/Library/Caches` |
| Preferences | `~/Library/Preferences` plists |
| Logs | `~/Library/Logs` |
| Auth tokens | Keychain-adjacent credential files |
| AI tool data | Claude Code, Cursor, Windsurf, Copilot, +20 more |
| Orphaned data | Library dirs with no owning app |
| XDG dirs | `~/.config`, `~/.local/share` |
| MAS receipts | Mac App Store install records |
| Application Support | `~/Library/Application Support` |

---

## AI Agent Skills

The built-in agent has 7 skills it can call:

| Skill | Description |
|-------|-------------|
| `list_apps` | List all installed applications |
| `scan_app` | Deep-scan a specific app |
| `scan_leftovers` | Find orphaned and AI tool leftovers |
| `list_processes` | List running background processes |
| `review_plan` | Review a pending uninstall plan |
| `plan_uninstall` | Draft an uninstall plan for review |
| `show_history` | Show past uninstall history |

All skills are read-only by default. The agent drafts plans — you approve removals.

---

## FAQ

**Is it safe?** Yes. Files go to Trash, not `/dev/null`. System paths are protected. Every deletion requires confirmation.

**Does it phone home?** No. No analytics, no telemetry, no network requests. All processing is local.

**Why not use AppCleaner / CleanMyMac?** Those are closed-source, some are paid, and none combine package manager cleanup, orphan scanning, AI assistance, and process management in one tool.

**Can I redistribute it?** Yes. MIT licensed. See [LICENSE](LICENSE).

---

## System Requirements

| Requirement | Minimum |
|-------------|---------|
| macOS | **14.0 (Sonoma)** or later |
| Architecture | Intel (x86-64) or Apple Silicon (arm64) |
| Disk | ~25 MB installed |

> **Why macOS 14?** Expunge uses SwiftUI APIs introduced in Sonoma — `.onKeyPress` for rich keyboard input handling, and the modern `.onChange(of:)` closure syntax. Supporting older versions would require replacing these with legacy equivalents, adding maintenance burden for a small team. Sonoma was released in 2023 and runs on all Macs from 2018 onward.

---

## License

MIT © Expunge contributors
