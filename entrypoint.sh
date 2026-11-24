#!/bin/sh
# Seed the persistent home with image defaults (missing files only), then restore apt packages
# recorded in the manifest. Runs as user dev.
set -eu
mkdir -p "$HOME/.config/opencode" "$HOME/.config/devws"
[ -f "$HOME/.config/opencode/opencode.json" ] || cp /opt/devws/defaults/opencode.json "$HOME/.config/opencode/opencode.json"
if [ ! -d "$HOME/.config/opencode/skill/lightpanda" ]; then
  mkdir -p "$HOME/.config/opencode/skill"
  cp -r /opt/devws/skills/. "$HOME/.config/opencode/skill/"
fi
mkdir -p "$HOME/work"

# Restore apt packages in the background so the server starts immediately.
MANIFEST="$HOME/.config/devws/apt-packages.txt"
if [ -s "$MANIFEST" ]; then
  (
    echo "$(date -u +%FT%TZ) restoring apt packages: $(tr '\n' ' ' < "$MANIFEST")"
    sudo /usr/bin/apt-get update -qq
    # shellcheck disable=SC2046
    sudo /usr/bin/apt-get install -y --no-install-recommends $(cat "$MANIFEST") && echo "$(date -u +%FT%TZ) apt restore done"
  ) > "$HOME/.config/devws/apt-restore.log" 2>&1 &
fi

exec "$@"
