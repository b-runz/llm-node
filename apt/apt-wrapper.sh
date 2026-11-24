#!/bin/bash
# /usr/local/bin/apt and apt-get: run as root (via sudo when called as dev), and record
# explicitly installed/removed packages in the persistent manifest so they can be restored.
set -u
NAME=$(basename "$0")
if [ "$(id -u)" -ne 0 ]; then
  exec sudo -- "$0" "$@"
fi
REAL="/usr/bin/$NAME"
mkdir -p /home/dev/.cache/apt-archives/partial   # the PVC may be fresh
MANIFEST=/home/dev/.config/devws/apt-packages.txt

sub=""; pkgs=()
for a in "$@"; do
  if [ -z "$sub" ]; then
    case "$a" in -*) ;; *) sub="$a" ;; esac
  elif [[ "$a" != -* ]]; then
    pkgs+=("$a")
  fi
done

"$REAL" "$@"; rc=$?
if [ "$rc" -eq 0 ] && [ "${#pkgs[@]}" -gt 0 ]; then
  case "$sub" in
    install)
      mkdir -p "$(dirname "$MANIFEST")"; touch "$MANIFEST"
      for p in "${pkgs[@]}"; do grep -qxF "$p" "$MANIFEST" || echo "$p" >> "$MANIFEST"; done
      chown -R dev:dev /home/dev/.config/devws ;;
    remove|purge)
      if [ -f "$MANIFEST" ]; then
        for p in "${pkgs[@]}"; do sed -i "\|^$p\$|d" "$MANIFEST"; done
        chown dev:dev "$MANIFEST"
      fi ;;
  esac
fi
exit "$rc"
