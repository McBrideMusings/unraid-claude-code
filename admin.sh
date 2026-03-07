#!/bin/bash
#
# Dev admin script for the Claude Code Unraid plugin.
#
# Set UNRAID_HOST in .env or environment.
#
# Usage:
#   ./admin.sh deploy              # Push source files (registers plugin if needed)
#   ./admin.sh clean               # Reset to fresh-install state (keeps plugin installed)
#   ./admin.sh uninstall           # Full removal from Unraid
#

set -euo pipefail

# Load .env if present
if [ -f "$(dirname "$0")/.env" ]; then
  set -a
  source "$(dirname "$0")/.env"
  set +a
fi

PLUGIN_NAME="claude-code"
PLUGIN_DIR="/boot/config/plugins/${PLUGIN_NAME}"
EMHTTP_DIR="/usr/local/emhttp/plugins/${PLUGIN_NAME}"
PLG_PATH="/boot/config/plugins/${PLUGIN_NAME}.plg"
CONFIG_DIR="${PLUGIN_DIR}/claude-config"

require_host() {
  if [ -z "${UNRAID_HOST:-}" ]; then
    echo "Error: UNRAID_HOST is not set. Create a .env file or export it."
    exit 1
  fi
}

generate_dev_plg() {
  cat <<'PLGEOF'
<?xml version='1.0' standalone='yes'?>
<!DOCTYPE PLUGIN [
  <!ENTITY name    "claude-code">
  <!ENTITY author  "McBrideMusings">
  <!ENTITY version "dev.TIMESTAMP">
  <!ENTITY launch  "Utilities/ClaudeCode">
]>
<PLUGIN name="&name;" author="&author;" version="&version;" launch="&launch;" min="6.12.0">
<CHANGES>
##&name; — dev build
</CHANGES>

<FILE Run="/bin/bash">
<INLINE>
PLUGIN="claude-code"
PLUGIN_DIR="/boot/config/plugins/${PLUGIN}"
CONFIG_DIR="${PLUGIN_DIR}/claude-config"

mkdir -p "${PLUGIN_DIR}/bin"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${CONFIG_DIR}/skills"
mkdir -p "${CONFIG_DIR}/commands"

if [ ! -f "${PLUGIN_DIR}/${PLUGIN}.cfg" ]; then
  cp /usr/local/emhttp/plugins/${PLUGIN}/default.cfg "${PLUGIN_DIR}/${PLUGIN}.cfg" 2>/dev/null || true
fi

if [ ! -f "${CONFIG_DIR}/CLAUDE.md" ]; then
  cp /usr/local/emhttp/plugins/${PLUGIN}/default-claude.md "${CONFIG_DIR}/CLAUDE.md" 2>/dev/null || true
fi

chmod +x /usr/local/emhttp/plugins/${PLUGIN}/scripts/* 2>/dev/null || true

BIN_CACHE="${PLUGIN_DIR}/bin/claude"
if [ -f "${BIN_CACHE}" ]; then
  VERSION=$("${BIN_CACHE}" --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo "latest")
  mkdir -p /root/.local/share/claude/versions
  mkdir -p /root/.local/bin
  cp "${BIN_CACHE}" "/root/.local/share/claude/versions/${VERSION}"
  chmod 755 "/root/.local/share/claude/versions/${VERSION}"
  ln -sf "/root/.local/share/claude/versions/${VERSION}" /root/.local/bin/claude
  cp "${BIN_CACHE}" /usr/local/bin/claude
  chmod 755 /usr/local/bin/claude
fi

if ! grep -q '\.local/bin' /root/.bash_profile 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /root/.bash_profile
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

# Pre-accept workspace trust for /root
if [ -f "${CONFIG_DIR}/.claude.json" ] && command -v python3 &>/dev/null; then
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

echo "Claude Code dev plugin registered."
</INLINE>
</FILE>

<FILE Run="/bin/bash" Method="remove">
<INLINE>
rm -f /usr/local/bin/claude
[ -L "/root/.claude" ] &amp;&amp; rm -f /root/.claude
rm -rf /usr/local/emhttp/plugins/claude-code
echo "Claude Code plugin removed."
</INLINE>
</FILE>
</PLUGIN>
PLGEOF
}

cmd_deploy() {
  require_host

  # Register if not already registered
  ssh "root@${UNRAID_HOST}" "test -f ${PLG_PATH}" 2>/dev/null || {
    echo "Plugin not registered. Registering..."
    generate_dev_plg | sed "s/TIMESTAMP/$(date +%s)/" | ssh "root@${UNRAID_HOST}" "cat > ${PLG_PATH} && plugin install ${PLG_PATH}"
  }

  echo "Deploying source files to ${UNRAID_HOST}..."
  ssh "root@${UNRAID_HOST}" "mkdir -p ${EMHTTP_DIR}/include ${EMHTTP_DIR}/scripts"
  scp -r source/usr/local/emhttp/plugins/${PLUGIN_NAME}/* "root@${UNRAID_HOST}:${EMHTTP_DIR}/"
  ssh "root@${UNRAID_HOST}" "chmod +x ${EMHTTP_DIR}/scripts/* 2>/dev/null || true"
  echo "Done."
}

cmd_clean() {
  require_host
  echo "Resetting to fresh-install state on ${UNRAID_HOST}..."
  ssh "root@${UNRAID_HOST}" "
    rm -f /usr/local/bin/claude
    rm -rf /root/.local/bin/claude /root/.local/share/claude
    rm -rf ${CONFIG_DIR}/*
    cp ${EMHTTP_DIR}/default-claude.md ${CONFIG_DIR}/CLAUDE.md 2>/dev/null || true
    cp ${EMHTTP_DIR}/default.cfg ${PLUGIN_DIR}/${PLUGIN_NAME}.cfg 2>/dev/null || true
    echo 'Config reset. Binary removed. Plugin still registered.'
  "
  echo "Done."
}

cmd_uninstall() {
  require_host
  echo "Fully uninstalling from ${UNRAID_HOST}..."
  ssh "root@${UNRAID_HOST}" "
    plugin remove ${PLUGIN_NAME}.plg 2>/dev/null || true
    rm -rf ${PLUGIN_DIR}
    echo 'Plugin and all data removed.'
  "
  echo "Done."
}

case "${1:-help}" in
  deploy)
    cmd_deploy
    ;;
  clean)
    cmd_clean
    ;;
  uninstall)
    cmd_uninstall
    ;;
  *)
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  deploy      Push source files to Unraid (registers if needed)"
    echo "  clean       Reset to fresh-install state (keeps plugin registered)"
    echo "  uninstall   Full removal (plugin + all data from USB)"
    echo ""
    echo "Environment (set in .env):"
    echo "  UNRAID_HOST   Hostname or IP of your Unraid server"
    ;;
esac
