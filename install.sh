#!/usr/bin/env bash
# Download and install a prebuilt `maic` release binary from GitHub.
#
#   curl -fsSL https://raw.githubusercontent.com/emarref/maic/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/emarref/maic/main/install.sh | bash -s -- v0.1.0-beta.1
#
# With no argument it installs the most recent release (including prereleases,
# while that's all there is). Pass a tag (e.g. v0.1.0) to pin an exact version.
#
# Env:
#   PREFIX   install directory (default: ~/.local/bin)
set -euo pipefail

REPO="emarref/maic"
PREFIX="${PREFIX:-$HOME/.local/bin}"

err() { echo "install: $*" >&2; exit 1; }

case "${1:-}" in
  -h|--help)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

# --- platform checks -------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || err "maic only runs on macOS."
arch="$(uname -m)"
[ "$arch" = "arm64" ] || err "maic ships arm64-only (Apple silicon); detected '$arch'."

for tool in curl tar shasum; do
  command -v "$tool" >/dev/null 2>&1 || err "required tool not found: $tool"
done

# --- resolve the release tag ----------------------------------------------
tag="${1:-}"
if [ -z "$tag" ]; then
  echo "Resolving latest release..." >&2
  tag="$(curl -fsSL "https://api.github.com/repos/$REPO/releases" \
          | grep -m1 '"tag_name"' \
          | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
  [ -n "$tag" ] || err "could not determine the latest release tag."
fi
version="${tag#v}"
echo "Installing maic $tag..." >&2

# --- download and verify ---------------------------------------------------
asset="maic-${version}-macos-arm64.tar.gz"
base="https://github.com/$REPO/releases/download/$tag"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "$base/$asset"        -o "$tmp/$asset"        || err "download failed: $base/$asset"
curl -fsSL "$base/$asset.sha256" -o "$tmp/$asset.sha256" || err "checksum download failed."
( cd "$tmp" && shasum -a 256 -c "$asset.sha256" >/dev/null 2>&1 ) \
  || err "checksum verification FAILED — refusing to install."
echo "Checksum OK." >&2

# --- extract and install ---------------------------------------------------
tar -xzf "$tmp/$asset" -C "$tmp"
binsrc="$tmp/maic-${version}-macos-arm64/maic"
[ -f "$binsrc" ] || err "binary not found in archive."

# curl downloads aren't quarantined, but clear the flag defensively anyway.
xattr -d com.apple.quarantine "$binsrc" 2>/dev/null || true

mkdir -p "$PREFIX"
install -m 0755 "$binsrc" "$PREFIX/maic"

ver="$("$PREFIX/maic" --version 2>/dev/null || true)"
echo "Installed: $PREFIX/maic${ver:+ ($ver)}" >&2

# --- shell integration -----------------------------------------------------
# maic places the suggested command on your zsh prompt (editable; nothing runs
# until you press Enter) via a small function. Wire it into ~/.zshrc, idempotently.
# Set MAIC_NO_SHELL_INIT=1 to skip this and get the manual instructions instead.
rc="${ZDOTDIR:-$HOME}/.zshrc"
begin="# >>> maic shell integration >>>"
end="# <<< maic shell integration <<<"

# The managed block prepends PREFIX to PATH only when it isn't already there,
# so the `eval` line can find `maic` at shell startup.
path_line=""
case ":$PATH:" in
  *":$PREFIX:"*) ;;
  *) path_line="export PATH=\"$PREFIX:\$PATH\"" ;;
esac

# Only wire in the `eval` if THIS binary actually understands `--init zsh`.
# A binary that predates the integration treats `--init zsh` as a plain-English
# task and asks the model, which happily returns something like `zsh -i` — and
# `eval "$(...)"` would then launch a nested interactive shell that hangs every
# new shell forever. Probing for the integration's sentinel line makes a
# version mismatch impossible to poison ~/.zshrc with.
init_sentinel="# maic shell integration (zsh)"
supports_init=""
if "$PREFIX/maic" --init zsh 2>/dev/null | grep -qF "$init_sentinel"; then
  supports_init=1
fi

if [ -z "$supports_init" ]; then
  echo "This maic ($tag) predates the zsh integration; not touching $rc." >&2
  echo "Upgrade to a release that supports 'maic --init zsh' to enable it." >&2
  [ -n "$path_line" ] && echo "Make sure this is on your PATH: $path_line" >&2
elif [ -n "${MAIC_NO_SHELL_INIT:-}" ]; then
  echo "Skipping shell integration (MAIC_NO_SHELL_INIT set). To enable it, add to $rc:" >&2
  [ -n "$path_line" ] && echo "  $path_line" >&2
  echo '  eval "$(maic --init zsh)"' >&2
else
  block="$begin"
  [ -n "$path_line" ] && block="$block
$path_line"
  block="$block
eval \"\$(maic --init zsh)\"
$end"

  touch "$rc"
  if grep -qF "$begin" "$rc"; then
    # Drop any existing managed block first, so re-running stays idempotent.
    awk -v b="$begin" -v e="$end" '
      $0==b {skip=1}
      skip  {if ($0==e) skip=0; next}
      {print}
    ' "$rc" > "$rc.maic.tmp" && mv "$rc.maic.tmp" "$rc"
  fi
  # Ensure a separating newline so the marker never fuses onto the user's last
  # line (a ~/.zshrc isn't guaranteed to end in a newline).
  if [ -s "$rc" ] && [ -n "$(tail -c1 "$rc")" ]; then
    printf '\n' >> "$rc"
  fi
  printf '%s\n' "$block" >> "$rc"
  echo "Enabled maic zsh integration in $rc." >&2
  echo "Start a new shell (or run: source $rc) to use it." >&2
  echo "To remove it, delete the block between the '$begin' / '$end' markers." >&2
fi
