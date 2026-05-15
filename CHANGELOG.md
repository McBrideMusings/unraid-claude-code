# Changelog

## Unreleased

## 2026.05.15

- New `claude` wrapper (`/usr/local/bin/claude`) that repairs the `/root/.claude.json` symlink on every launch. Defends against Claude Code's built-in corruption rotation, which would otherwise replace the symlink with a fresh real file in RAM and silently strand the USB-persisted config.
- Hardened boot-time `.claude.json` handling in `doinst.sh` and the `.plg` INLINE: atomic writes, no clobber on parse failure, idempotent trust-accept.
- USB source-of-truth safeguard: after first install (marked by `.bootstrapped`), stray RAM-side `/root/.claude[.json]` is rescued to `/tmp` instead of merging into USB.
- `./admin deploy` now always overwrites the `.plg` on USB (previously skipped if one was already registered, which silently stranded users who'd first installed from the released package). Deploy also pushes the wrapper to USB and drops the `.bootstrapped` marker.
- Boot-time `PATH` now puts `/usr/local/bin` ahead of `~/.local/bin` so the wrapper wins over any auto-update symlink Claude's installer may write.
- Fix `Makefile` `PLUGIN_VER` typo (`2025.03.06` → matched version).

## 2026.03.06

Initial public release.

- Claude Code CLI install with persistent binary cache on USB flash
- WebGUI page with Status, Configuration, Skills, and Commands tabs
- Config editors for global CLAUDE.md and settings.json
- Skills and Commands file management (create, edit, delete)
- Auth token and config persistence across reboots via USB symlinks
- Documentation links in Configuration tab
- Launch Claude in web terminal from WebGUI
- Update and uninstall controls in WebGUI
