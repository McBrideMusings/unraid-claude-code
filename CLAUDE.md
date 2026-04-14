# CLAUDE.md

## Project

This is an Unraid plugin that installs Claude Code CLI with persistence across reboots. The plugin caches the binary on USB flash, symlinks `~/.claude/` and `~/.claude.json` to USB for auth/config persistence, and provides a WebGUI settings page.

## Structure

- `claude-code.plg` — Plugin installer (XML). Downloads `.txz` package from GitHub Releases, then runs post-install script for binary download and config symlink.
- `source/` — Files that get packaged into the plugin `.txz`. Mirrors the filesystem layout on the Unraid server.
- `Makefile` — Builds the `.txz` package locally (requires Slackware `makepkg`).
- `.github/workflows/release.yml` — CI/CD: tag push triggers build, release, and checksum patching.
- `admin` — Dev task runner (deploy to local Unraid for testing). Requires `UNRAID_HOST` in `.env`.

## Key Files

- `source/install/doinst.sh` — Boot-time setup: symlinks config, restores binary from USB cache, sets PATH, pre-accepts workspace trust.
- `source/usr/local/emhttp/plugins/claude-code/ClaudeCode.page` — WebGUI page (Status, Configuration, Skills, Commands tabs).
- `source/usr/local/emhttp/plugins/claude-code/include/claude-code-api.php` — PHP backend API for status checks, file editing, skills/commands CRUD, updates.
- `source/usr/local/emhttp/plugins/claude-code/include/open-claude.php` — Spawns ttyd web terminal running `claude`.
- `source/usr/local/emhttp/plugins/claude-code/scripts/update-claude` — Downloads Claude Code via official installer with vfat workaround.
- `source/usr/local/emhttp/plugins/claude-code/images/claude-code.png` — Plugin icon (from lobehub/lobe-icons).

## Conventions

- Follow standard Unraid plugin packaging conventions.
- Source files in `source/` mirror the installed filesystem path (e.g., `source/usr/local/emhttp/plugins/claude-code/`).
- The `.plg` downloads pre-built `.txz` packages from GitHub Releases — it does NOT inline file contents.
- Binary download happens at install time on the Unraid server (not at build time) because Claude Code doesn't publish static release binaries.
- The official installer (`curl -fsSL https://claude.ai/install.sh | bash`) is used with a tmpdir HOME workaround because USB flash is vfat (noexec).
- WebGUI JS functions must be prefixed with `claude` (e.g., `claudeSwitchTab`) to avoid colliding with Unraid's global JS namespace.

## Persistence Details

- `/root/.claude/` → symlink to `/boot/config/plugins/claude-code/claude-config/` (auth tokens, settings, memory, skills, commands)
- `/root/.claude.json` → symlink to USB-persistent copy (workspace trust, onboarding state, cached features)
- Binary cached at `/boot/config/plugins/claude-code/bin/claude`, copied to RAM at `/usr/local/bin/claude` and native structure at `~/.local/share/claude/versions/<ver>`
- PATH export added to `/root/.bash_profile` (login shells) and `/etc/profile.d/claude-code.sh` (all shells, RAM-based, recreated on boot)
- **USB is source of truth after first install.** A `.bootstrapped` marker in `claude-config/` gates one-time RAM→USB migration. On every boot after, any stray real file/dir at `/root/.claude[.json]` is moved to `/tmp/claude-ram-rescue-<ts>/` rather than merged into USB.

## Dev Deploy

```bash
# Set UNRAID_HOST in .env file
./admin deploy      # Push source files (auto-registers plugin if needed)
./admin clean       # Reset to fresh-install state (keeps plugin registered)
./admin uninstall   # Full removal
```

## Unraid Plugin Basics

- Unraid boots from USB into RAM. Only `/boot/` persists across reboots.
- Plugins use `.plg` (XML) files that define packages to download and scripts to run.
- WebGUI pages go in `/usr/local/emhttp/plugins/<name>/` and are PHP-based.
- Plugin config persists at `/boot/config/plugins/<name>/`.
- `/boot` is vfat — no exec permissions, no symlink support on the filesystem itself.
- Login shells source `.bash_profile`, not `.bashrc` (Slackware behavior).
