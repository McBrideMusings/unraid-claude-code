# Changelog

## Unreleased

- Hardened boot-time `.claude.json` handling: atomic writes, no clobber on parse failure, idempotent trust-accept.
- USB source-of-truth safeguard: after first install, stray RAM-side `/root/.claude[.json]` is rescued to `/tmp` instead of merging into USB.

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
