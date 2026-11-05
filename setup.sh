#!/usr/bin/env bash
# Generate opencode.json from opencode.json.template.
#
# The llama-server URL is taken from, in this order:
#   1. the first argument:      ./setup.sh http://host:8081/v1
#   2. OPENCODE_BASE_URL in .env (next to this script)
#   3. an interactive prompt
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$DIR/opencode.json.template"
OUTPUT="$DIR/opencode.json"
ENV_FILE="$DIR/.env"
PLACEHOLDER="__OPENCODE_BASE_URL__"

[ -f "$TEMPLATE" ] || { echo "error: template not found: $TEMPLATE" >&2; exit 1; }

# Read OPENCODE_BASE_URL from .env without sourcing it (no code execution).
read_env_url() {
  [ -f "$ENV_FILE" ] || return 0
  local line
  line="$(grep -E '^[[:space:]]*(export[[:space:]]+)?OPENCODE_BASE_URL=' "$ENV_FILE" | tail -n 1 || true)"
  [ -n "$line" ] || return 0
  line="${line#*=}"
  line="${line%$'\r'}"
  # strip surrounding quotes
  line="${line#\"}"; line="${line%\"}"
  line="${line#\'}"; line="${line%\'}"
  printf '%s' "$line"
}

url=""
source_desc=""
if [ $# -ge 1 ] && [ -n "$1" ]; then
  url="$1"; source_desc="argument"
else
  url="$(read_env_url)"
  [ -n "$url" ] && source_desc=".env"
fi

if [ -z "$url" ]; then
  if [ ! -t 0 ]; then
    echo "error: no URL given and no OPENCODE_BASE_URL in $ENV_FILE (and stdin is not a terminal)" >&2
    exit 1
  fi
  read -r -p "llama-server base URL (e.g. http://myhost:8081/v1): " url
  source_desc="input"
  [ -n "$url" ] || { echo "error: no URL entered" >&2; exit 1; }

  if [ ! -f "$ENV_FILE" ] || [ -z "$(read_env_url)" ]; then
    read -r -p "Save it to .env for next time? [Y/n] " answer
    case "${answer:-y}" in
      [Yy]*) printf 'OPENCODE_BASE_URL=%s\n' "$url" >> "$ENV_FILE"; chmod 600 "$ENV_FILE"; echo "Saved to $ENV_FILE" ;;
    esac
  fi
fi

case "$url" in
  http://*|https://*) ;;
  *) echo "error: URL must start with http:// or https:// (got: $url)" >&2; exit 1 ;;
esac
case "$url" in
  */v1|*/v1/) ;;
  *) echo "warning: URL doesn't end in /v1; llama-server's OpenAI-compatible API usually lives there" >&2 ;;
esac
case "$url" in
  *\"*|*\\*) echo "error: URL must not contain quotes or backslashes" >&2; exit 1 ;;
esac

# Back up an existing config that differs from what we're about to write.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
# awk with index() does a literal replacement, so characters like & or | in the URL are safe.
URL="$url" PH="$PLACEHOLDER" awk '
  { while ((i = index($0, ENVIRON["PH"])) > 0)
      $0 = substr($0, 1, i - 1) ENVIRON["URL"] substr($0, i + length(ENVIRON["PH"]))
    print }' "$TEMPLATE" > "$tmp"

if [ -f "$OUTPUT" ] && ! cmp -s "$tmp" "$OUTPUT"; then
  cp "$OUTPUT" "$OUTPUT.bak"
  echo "Backed up previous config to $OUTPUT.bak"
fi
mv "$tmp" "$OUTPUT"
trap - EXIT

echo "Wrote $OUTPUT (baseURL from $source_desc: $url)"
echo "Restart opencode to pick up the change."
