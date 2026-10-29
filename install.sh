#!/usr/bin/env bash
# Installs git-identity and its Secretive signing wrapper into ~/.local/bin.
#   from a clone:     ./install.sh
#   one line, no clone:   curl -fsSL https://raw.githubusercontent.com/masterde/git-identity/main/install.sh | bash
set -euo pipefail
RAW=https://raw.githubusercontent.com/masterde/git-identity/main
BIN="$HOME/.local/bin"; mkdir -p "$BIN"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)"
fetch() { if command -v curl >/dev/null; then curl -fsSL "$1"; else wget -qO- "$1"; fi; }
for f in git-identity git-identity-keygen; do
  if [ -n "$SRC" ] && [ -f "$SRC/$f" ]; then install -m 755 "$SRC/$f" "$BIN/$f"
  else fetch "$RAW/$f" > "$BIN/$f.tmp" && head -1 "$BIN/$f.tmp" | grep -q '^#!' || { rm -f "$BIN/$f.tmp"; echo "download of $f failed" >&2; exit 1; }; mv "$BIN/$f.tmp" "$BIN/$f"; chmod 755 "$BIN/$f"; fi
done
bash -n "$BIN/git-identity"
echo "installed $BIN/git-identity ($( "$BIN/git-identity" help 2>/dev/null | sed -n '1p' | sed 's/^# //' ))"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "add $BIN to PATH (e.g. in ~/.zprofile or ~/.profile), then";; esac
echo "run 'git identity' inside a clone"
