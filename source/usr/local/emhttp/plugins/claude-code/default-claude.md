# Unraid Server

This file is the global CLAUDE.md for Claude Code on this Unraid server. It persists across reboots at `/boot/config/plugins/claude-code/claude-config/CLAUDE.md`.

## Filesystem Persistence

Unraid boots from USB flash into RAM. Most of the filesystem is **not persistent** — files written to RAM are lost on reboot.

### Persistent locations (survive reboots)
- `/boot/` — USB flash drive (OS config, plugin data, startup scripts)
- `/boot/config/plugins/` — Plugin configuration and data
- `/boot/config/go` — Startup script (runs on every boot)
- `/mnt/user/` — Array and pool storage (user data, Docker appdata)
- `/mnt/cache/`, `/mnt/disk*` — Direct disk/pool access
- `/mnt/user/appdata/` — Docker container configuration

### Non-persistent locations (lost on reboot)
- `/root/` — Root home directory (RAM)
- `/etc/` — System configuration (RAM)
- `/tmp/`, `/var/` — Temporary and runtime data (RAM)
- `/usr/local/` — Installed binaries and plugins (RAM, rebuilt from USB on boot)

### Important for Claude Code
- **Do not store project files, notes, or memory in `/root/`, `/tmp/`, or `/etc/`** — they will be lost on reboot.
- **This CLAUDE.md and all `~/.claude/` contents are persistent** — they are symlinked to USB flash.
- If asked to save files or create projects, prefer `/mnt/user/` (array storage) or `/boot/config/` (USB flash) for persistence.
- If asked to modify system config in `/etc/`, note that changes require entries in `/boot/config/go` to persist across reboots.

## Docker Management

- Containers are managed via the Unraid Docker GUI or `docker` CLI
- No docker-compose — Unraid does not natively support it
- Container appdata lives at `/mnt/user/appdata/<container>/`
- Docker config: `/boot/config/plugins/dockerMan/`

## Common Tasks

- **View running containers:** `docker ps`
- **Check array status:** Read from `/var/local/emhttp/disks.ini` or use the WebGUI
- **Plugin management:** `plugin install/remove/check <url>`
- **Persistent startup commands:** Add to `/boot/config/go`
