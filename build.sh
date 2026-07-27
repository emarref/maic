#!/bin/zsh
# Build `maic` in release mode and install it to a bin dir on your PATH.
set -euo pipefail

cd "$(dirname "$0")"

PREFIX="${PREFIX:-$HOME/.local/bin}"

# maic needs FoundationModels, which only exists on macOS 26+. Fail early with a
# clear message rather than letting `swift build` emit an opaque SDK error.
os_ver="$(sw_vers -productVersion)"
[ "${os_ver%%.*}" -ge 26 ] 2>/dev/null || { echo "build: maic requires macOS 26 or later (detected $os_ver)." >&2; exit 1; }

echo "Building (release)…"
swift build -c release

mkdir -p "$PREFIX"
cp -f .build/release/maic "$PREFIX/maic"

echo "Installed: $PREFIX/maic"
case ":$PATH:" in
  *":$PREFIX:"*) ;;
  *) echo "Note: $PREFIX is not on your PATH. Add this to ~/.zshrc:"
     echo "  export PATH=\"$PREFIX:\$PATH\"" ;;
esac

# The release installer (install.sh) wires the zsh integration into ~/.zshrc for
# you. From a source build, enable it yourself by adding this to ~/.zshrc:
echo 'For the "put the command on my prompt" behaviour, add to ~/.zshrc:'
echo '  eval "$(maic --init zsh)"'
