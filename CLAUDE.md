# CLAUDE.md

## Project

This is an Unraid plugin that installs Claude Code CLI with persistence across reboots. The plugin caches the binary on USB flash, symlinks `~/.claude/` to USB for auth/config persistence, and provides a WebGUI settings page.

## Structure

- `claude-code.plg` — Plugin installer (XML). Downloads `.txz` package from GitHub Releases, then runs post-install script for binary download and config symlink.
- `source/` — Files that get packaged into the plugin `.txz`. Mirrors the filesystem layout on the Unraid server.
- `Makefile` — Builds the `.txz` package locally (requires Slackware `makepkg`).
- `.github/workflows/release.yml` — CI/CD: tag push triggers build, release, and checksum patching.
- `admin.sh` — Dev admin script (deploy to local Unraid for testing). Requires `UNRAID_HOST` env var.

## Conventions

- Follow standard Unraid plugin packaging conventions.
- Source files in `source/` mirror the installed filesystem path (e.g., `source/usr/local/emhttp/plugins/claude-code/`).
- The `.plg` downloads pre-built `.txz` packages from GitHub Releases — it does NOT inline file contents.
- Binary download happens at install time on the Unraid server (not at build time) because Claude Code doesn't publish static release binaries.

## Dev Deploy

```bash
UNRAID_HOST=<host> ./admin.sh deploy           # Deploy everything to Unraid
UNRAID_HOST=<host> ./admin.sh deploy files     # Source files only (fast iteration)
```

## Unraid Plugin Basics

- Unraid boots from USB into RAM. Only `/boot/` persists across reboots.
- Plugins use `.plg` (XML) files that define packages to download and scripts to run.
- WebGUI pages go in `/usr/local/emhttp/plugins/<name>/` and are PHP-based.
- Plugin config persists at `/boot/config/plugins/<name>/`.
