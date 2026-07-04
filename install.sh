#!/usr/bin/env bash
set -euo pipefail

CURSOR_DIR="${HOME}/.cursor"
SCRIPT_PATH="${CURSOR_DIR}/statusline-command.sh"
CONFIG_PATH="${CURSOR_DIR}/cli-config.json"
RAW_URL="https://raw.githubusercontent.com/matheustimbo/agent-status-line/main/statusline-command.sh"

PADDING="${PADDING:-2}"
UPDATE_INTERVAL_MS="${UPDATE_INTERVAL_MS:-1000}"
TIMEOUT_MS="${TIMEOUT_MS:-2000}"
ENABLE_CURSOR_USAGE="${ENABLE_CURSOR_USAGE:-0}"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required." >&2
  echo "  macOS: brew install jq" >&2
  echo "  Linux: apt install jq (or your distro equivalent)" >&2
  exit 1
fi

mkdir -p "$CURSOR_DIR"

if [ -n "${LOCAL_SCRIPT:-}" ]; then
  echo "Installing local status line script from $LOCAL_SCRIPT to $SCRIPT_PATH"
  cp "$LOCAL_SCRIPT" "$SCRIPT_PATH"
else
  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required." >&2
    exit 1
  fi

  echo "Downloading status line script to $SCRIPT_PATH"
  curl -fsSL "$RAW_URL" -o "$SCRIPT_PATH"
fi

chmod +x "$SCRIPT_PATH"

STATUSLINE_COMMAND="~/.cursor/statusline-command.sh"
if [ "$ENABLE_CURSOR_USAGE" != "0" ]; then
  STATUSLINE_COMMAND="bash -lc 'SHOW_CURSOR_USAGE=1 ~/.cursor/statusline-command.sh'"
fi

STATUSLINE_BLOCK=$(jq -n \
  --arg command "$STATUSLINE_COMMAND" \
  --argjson padding "$PADDING" \
  --argjson updateIntervalMs "$UPDATE_INTERVAL_MS" \
  --argjson timeoutMs "$TIMEOUT_MS" \
  '{
    type: "command",
    command: $command,
    padding: $padding,
    updateIntervalMs: $updateIntervalMs,
    timeoutMs: $timeoutMs
  }')

if [ -f "$CONFIG_PATH" ]; then
  echo "Updating $CONFIG_PATH (statusLine block)"
  tmp=$(mktemp)
  jq --argjson sl "$STATUSLINE_BLOCK" '.statusLine = $sl' "$CONFIG_PATH" > "$tmp"
  mv "$tmp" "$CONFIG_PATH"
else
  echo "Creating $CONFIG_PATH"
  jq -n --argjson sl "$STATUSLINE_BLOCK" '{version: 1, statusLine: $sl}' > "$CONFIG_PATH"
fi

echo
echo "Done. Restart Agent CLI to see the status line."
