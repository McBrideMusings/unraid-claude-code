# Claude Code for Unraid

A native Unraid plugin that installs [Claude Code](https://claude.ai/code) CLI and persists it across reboots. Auth tokens, config, memory, and skills are stored on the USB flash drive.

## Install

In the Unraid web UI, go to **Plugins > Install Plugin** and paste:

```
https://raw.githubusercontent.com/McBrideMusings/unraid-claude-code/main/claude-code.plg
```

## First-Time Setup

After installing, SSH into your server and authenticate:

```bash
claude login
```

This uses Claude Max OAuth. Tokens are stored in `/root/.claude/` which symlinks to USB flash, so credentials survive reboots.

Verify with:

```bash
claude --version
claude
```

## Features

- **Persistent binary** cached on USB flash, copied to RAM on boot
- **Persistent config** via symlink from `/root/.claude/` and `/root/.claude.json` to USB flash
- **WebGUI page** at Utilities > Claude Code for status, config editing, and skills browsing
- **Launch Claude** button opens a web terminal running Claude Code
- **No boot delay** — binary is only downloaded on first install or manual update, not every boot

## WebGUI

Navigate to **Utilities > Claude Code** in the Unraid WebGUI:

| Tab | Description |
|-----|-------------|
| **Status** | Version, auth status, Launch Claude button, Update button |
| **Configuration** | Edit global `CLAUDE.md` and `settings.json` |
| **Skills** | View and edit installed skills |

## Configuration

All persistent data lives on the USB flash drive at `/boot/config/plugins/claude-code/`:

| Path | Purpose |
|------|---------|
| `claude-code.cfg` | Plugin settings |
| `bin/claude` | Cached binary |
| `claude-config/` | Auth, memory, settings (symlink target for `~/.claude/`) |
| `claude-config/.claude.json` | Workspace trust, onboarding state (symlink target for `~/.claude.json`) |

Config is preserved across plugin updates and removals.

## Architecture

```
┌────────────────────────────────────────────┐
│ Unraid Plugin UI                           │
│  ClaudeCode.page  <-->  claude-code-api.php │
└────────────┬───────────────────────────────┘
             │
     ┌───────▼───────────┐
     │ /usr/local/bin/    │
     │ claude             │  <-- copied from USB cache on boot
     └───────────────────┘
             │
     ┌───────▼───────────┐
     │ /root/.claude/     │  --> /boot/config/plugins/claude-code/claude-config/
     │ (symlink to USB)   │      auth tokens, CLAUDE.md, settings.json, skills
     └───────────────────┘
```

## Development

### Quick testing

SCP files directly to the server without a full release:

```bash
# Create .env with UNRAID_HOST=<your-server-ip>
./admin.sh deploy      # Push source files (auto-registers if needed)
./admin.sh clean       # Reset to fresh-install state
./admin.sh uninstall   # Full removal
```

### Local build

```bash
make all          # Build plugin .txz package
make checksums    # Show MD5 for updating .plg
```

### Release

Tag-triggered via GitHub Actions:

```bash
git tag v2025.03.06
git push origin v2025.03.06
```

The workflow builds the plugin `.txz`, creates a GitHub release, and patches the `.plg` with the updated checksum on main.

## File Structure

```
claude-code.plg                              # Plugin installer (XML)
Makefile                                     # Local dev builds
.github/workflows/release.yml               # CI/CD pipeline
admin.sh                                    # Dev deploy script
source/
├── install/
│   ├── doinst.sh                           # Post-install setup
│   └── slack-desc                          # Package metadata
└── usr/local/emhttp/plugins/claude-code/
    ├── ClaudeCode.page                     # WebGUI page
    ├── default.cfg                         # Default config template
    ├── default-claude.md                   # Default CLAUDE.md template
    ├── images/
    │   ├── claude-code.png                 # Plugin icon
    │   └── claude-code.svg                 # Plugin icon (source)
    ├── include/
    │   ├── claude-code-api.php             # Backend API
    │   └── open-claude.php                 # Web terminal launcher
    └── scripts/
        └── update-claude                   # Binary update script
```
