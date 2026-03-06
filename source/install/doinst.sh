#!/bin/bash

PLUGIN_NAME="claude-code"
PLUGIN_DIR="/boot/config/plugins/${PLUGIN_NAME}"
CONFIG_DIR="${PLUGIN_DIR}/claude-config"
BIN_CACHE="${PLUGIN_DIR}/bin/claude"

# Create persistent directories on USB flash
mkdir -p "${PLUGIN_DIR}/bin"
mkdir -p "${CONFIG_DIR}"

# Create default config if missing
if [ ! -f "${PLUGIN_DIR}/${PLUGIN_NAME}.cfg" ]; then
  cp /usr/local/emhttp/plugins/${PLUGIN_NAME}/default.cfg "${PLUGIN_DIR}/${PLUGIN_NAME}.cfg"
fi

# Prefill global CLAUDE.md if none exists
if [ ! -f "${CONFIG_DIR}/CLAUDE.md" ]; then
  cp /usr/local/emhttp/plugins/${PLUGIN_NAME}/default-claude.md "${CONFIG_DIR}/CLAUDE.md" 2>/dev/null || true
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
