#!/bin/bash

PLUGIN_NAME="claude-code"
PLUGIN_DIR="/boot/config/plugins/${PLUGIN_NAME}"
CONFIG_DIR="${PLUGIN_DIR}/claude-config"
BIN_CACHE="${PLUGIN_DIR}/bin/claude"
BOOTSTRAP_MARKER="${CONFIG_DIR}/.bootstrapped"
RESCUE_DIR="/tmp/claude-ram-rescue-$(date +%s)"

# Create persistent directories on USB flash
mkdir -p "${PLUGIN_DIR}/bin"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${CONFIG_DIR}/skills"
mkdir -p "${CONFIG_DIR}/commands"

# Create default config if missing
if [ ! -f "${PLUGIN_DIR}/${PLUGIN_NAME}.cfg" ]; then
  cp /usr/local/emhttp/plugins/${PLUGIN_NAME}/default.cfg "${PLUGIN_DIR}/${PLUGIN_NAME}.cfg"
fi

# Prefill global CLAUDE.md if none exists
if [ ! -f "${CONFIG_DIR}/CLAUDE.md" ]; then
  cp /usr/local/emhttp/plugins/${PLUGIN_NAME}/default-claude.md "${CONFIG_DIR}/CLAUDE.md" 2>/dev/null || true
fi

# Symlink /root/.claude.json to USB-persistent copy.
# After first install (marker present), USB is source of truth and any RAM-side real file
# is rescued to /tmp rather than merged into USB.
if [ -f "${BOOTSTRAP_MARKER}" ]; then
  if [ -L "/root/.claude.json" ]; then
    [ "$(readlink /root/.claude.json)" != "${CONFIG_DIR}/.claude.json" ] && rm -f /root/.claude.json
  elif [ -e "/root/.claude.json" ]; then
    mkdir -p "${RESCUE_DIR}"
    mv /root/.claude.json "${RESCUE_DIR}/.claude.json" 2>/dev/null || rm -f /root/.claude.json
    echo "USB source-of-truth: moved /root/.claude.json to ${RESCUE_DIR}/"
  fi
else
  if [ -L "/root/.claude.json" ]; then
    [ "$(readlink /root/.claude.json)" != "${CONFIG_DIR}/.claude.json" ] && rm -f /root/.claude.json
  elif [ -f "/root/.claude.json" ]; then
    cp /root/.claude.json "${CONFIG_DIR}/.claude.json" 2>/dev/null || true
    rm -f /root/.claude.json
  fi
fi
[ -f "${CONFIG_DIR}/.claude.json" ] || touch "${CONFIG_DIR}/.claude.json"
[ -L "/root/.claude.json" ] || ln -sf "${CONFIG_DIR}/.claude.json" /root/.claude.json

# Pre-accept workspace trust for /root (Claude Code doesn't persist this on its own).
# Safety: on any failure we exit 0 without writing, so a bad parse never clobbers the user's config.
if [ -f "${CONFIG_DIR}/.claude.json" ]; then
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, os, sys
p = '${CONFIG_DIR}/.claude.json'
try:
    if not os.path.exists(p) or os.path.getsize(p) == 0:
        d = {}
    else:
        with open(p) as f:
            d = json.load(f)
    if not isinstance(d, dict):
        sys.exit(0)
    if d.get('projects', {}).get('/root', {}).get('hasTrustDialogAccepted') is True:
        sys.exit(0)
    d.setdefault('projects', {}).setdefault('/root', {})['hasTrustDialogAccepted'] = True
    tmp = p + '.tmp'
    try:
        with open(tmp, 'w') as f:
            json.dump(d, f, indent=2)
        os.replace(tmp, p)
    finally:
        if os.path.exists(tmp):
            try: os.remove(tmp)
            except Exception: pass
except Exception:
    sys.exit(0)
" 2>/dev/null || true
  fi
fi

# Symlink /root/.claude/ to USB-persistent config directory.
# After first install (marker present), USB is source of truth and any RAM-side real dir
# is rescued to /tmp rather than merged into USB.
if [ -f "${BOOTSTRAP_MARKER}" ]; then
  if [ -L "/root/.claude" ]; then
    [ "$(readlink /root/.claude)" != "${CONFIG_DIR}" ] && rm -f /root/.claude
  elif [ -e "/root/.claude" ]; then
    mkdir -p "${RESCUE_DIR}"
    mv /root/.claude "${RESCUE_DIR}/.claude" 2>/dev/null || rm -rf /root/.claude
    echo "USB source-of-truth: moved /root/.claude to ${RESCUE_DIR}/"
  fi
else
  if [ -L "/root/.claude" ]; then
    [ "$(readlink -f /root/.claude)" != "${CONFIG_DIR}" ] && rm -f /root/.claude
  elif [ -d "/root/.claude" ]; then
    cp -a /root/.claude/. "${CONFIG_DIR}/" 2>/dev/null || true
    rm -rf /root/.claude
  fi
fi
[ -L "/root/.claude" ] || ln -s "${CONFIG_DIR}" /root/.claude

# Restore native binary from USB cache on boot
if [ -f "${BIN_CACHE}" ]; then
  # Detect version from the binary
  VERSION=$("${BIN_CACHE}" --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo "latest")

  # Set up native install structure (what `claude install` expects)
  mkdir -p /root/.local/share/claude/versions
  mkdir -p /root/.local/bin
  cp "${BIN_CACHE}" "/root/.local/share/claude/versions/${VERSION}"
  chmod 755 "/root/.local/share/claude/versions/${VERSION}"
  ln -sf "/root/.local/share/claude/versions/${VERSION}" /root/.local/bin/claude

  # Also at /usr/local/bin for convenience
  cp "${BIN_CACHE}" /usr/local/bin/claude
  chmod 755 /usr/local/bin/claude
fi

# Ensure ~/.local/bin is in PATH for all shell types
if ! grep -q '\.local/bin' /root/.bash_profile 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /root/.bash_profile
fi
# Also add to /etc/profile.d/ so non-login shells pick it up (RAM-based, recreated on boot)
mkdir -p /etc/profile.d
echo 'export PATH="$HOME/.local/bin:$PATH"' > /etc/profile.d/claude-code.sh

# Mark first-install complete so future boots take the USB-wins path.
touch "${BOOTSTRAP_MARKER}" 2>/dev/null || true
