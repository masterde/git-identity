#!/usr/bin/env bash
# Installs git-identity (and the Secretive signing wrapper) into ~/.local/bin.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$HOME/.local/bin"
install -m 755 "$D/git-identity" "$HOME/.local/bin/git-identity"
install -m 755 "$D/git-identity-keygen" "$HOME/.local/bin/git-identity-keygen"
case ":$PATH:" in *":$HOME/.local/bin:"*) echo "installed; run 'git identity' inside a clone";; *) echo "installed; add ~/.local/bin to PATH (e.g. in ~/.zprofile), then run 'git identity' inside a clone";; esac
