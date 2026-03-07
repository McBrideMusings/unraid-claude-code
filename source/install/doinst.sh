#!/bin/bash

PLUGIN_NAME="claude-code"
PLUGIN_DIR="/boot/config/plugins/${PLUGIN_NAME}"
CONFIG_DIR="${PLUGIN_DIR}/claude-config"
BIN_CACHE="${PLUGIN_DIR}/bin/claude"

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

# Symlink /root/.claude.json to USB-persistent copy
if [ -f "/root/.claude.json" ] && [ ! -L "/root/.claude.json" ]; then
  cp /root/.claude.json "${CONFIG_DIR}/.claude.json" 2>/dev/null || true
fi
if [ -f "${CONFIG_DIR}/.claude.json" ]; then
  ln -sf "${CONFIG_DIR}/.claude.json" /root/.claude.json
else
  touch "${CONFIG_DIR}/.claude.json"
  ln -sf "${CONFIG_DIR}/.claude.json" /root/.claude.json
fi

# Pre-accept workspace trust for /root (Claude Code doesn't persist this on its own)
if [ -f "${CONFIG_DIR}/.claude.json" ]; then
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, os
p = '${CONFIG_DIR}/.claude.json'
try:
    d = json.load(open(p)) if os.path.getsize(p) > 0 else {}
except: d = {}
d.setdefault('projects', {}).setdefault('/root', {})['hasTrustDialogAccepted'] = True
json.dump(d, open(p, 'w'), indent=2)
" 2>/dev/null || true
  fi
fi

# Symlink /root/.claude/ to USB-persistent config directory
if [ -L "/root/.claude" ]; then
  CURRENT_TARGET=$(readlink -f /root/.claude)
  if [ "${CURRENT_TARGET}" != "${CONFIG_DIR}" ]; then
    rm -f /root/.claude
    ln -s "${CONFIG_DIR}" /root/.claude
  fi
elif [ -d "/root/.claude" ]; then
  cp -a /root/.claude/. "${CONFIG_DIR}/"
  rm -rf /root/.claude
  ln -s "${CONFIG_DIR}" /root/.claude
else
  ln -s "${CONFIG_DIR}" /root/.claude
fi

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
