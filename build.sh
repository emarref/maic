#!/bin/zsh
# Build `maic` in release mode and install it to a bin dir on your PATH.
set -euo pipefail

cd "$(dirname "$0")"

PREFIX="${PREFIX:-$HOME/.local/bin}"

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
