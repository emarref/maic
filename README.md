# maic

*Puts the AI in mac.*

[![CI](https://github.com/emarref/maic/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/emarref/maic/actions/workflows/ci.yml)

A tiny local CLI that turns a plain-English description into the right **macOS-specific**
shell command, using the on-device model shipped with macOS (Apple's
[FoundationModels](https://developer.apple.com/documentation/foundationmodels) framework).

Everything runs on-device — no network, no API key, nothing leaves your Mac.

```
$ maic list files in this dir sorted by size, largest first
ls -laS

$ maic show my primary local IP address
ipconfig getifaddr en0
```

With the zsh integration enabled, the suggested command is placed **on your prompt**
instead of just printed — ready to run, edit, or discard, exactly as if you'd typed it:

```
$ maic flush the DNS cache
# …a beat while the on-device model thinks…
$ sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder█   ← now on your prompt
```

Press **Enter** to run it (it lands in your shell history like any command you typed),
edit it first, or **Ctrl-C** to discard. Nothing runs on its own.

Because it's told to assume the BSD userland that ships with macOS, it prefers
`stat -f`, `sed -i ''`, `pbcopy`, `mdfind`, `networksetup`, etc. — not GNU/Linux flags.

## Requirements

- macOS 26 or later on Apple-Intelligence-capable hardware (Apple silicon).
- **Apple Intelligence must be turned on:** System Settings → Apple Intelligence & Siri →
  turn on Apple Intelligence. The model downloads in the background the first time;
  until it's ready `maic` will tell you so.
- Xcode Command Line Tools (`xcode-select --install`) — full Xcode is not required.

## Install

One line — downloads the latest release, verifies its checksum, installs to `~/.local/bin`,
and enables the [zsh integration](#shell-integration-zsh) (set `MAIC_NO_SHELL_INIT=1` to skip that):

```
curl -fsSL https://raw.githubusercontent.com/emarref/maic/main/install.sh | bash
```

Pin a specific version, or install somewhere else:

```
curl -fsSL https://raw.githubusercontent.com/emarref/maic/main/install.sh | bash -s -- v0.1.0-beta.1
curl -fsSL https://raw.githubusercontent.com/emarref/maic/main/install.sh | PREFIX=/usr/local/bin bash
```

## Download a release manually

Prebuilt arm64 binaries are attached to each [GitHub Release](https://github.com/emarref/maic/releases).
Download `maic-<version>-macos-arm64.tar.gz`, then:

```
tar -xzf maic-<version>-macos-arm64.tar.gz
cd maic-<version>-macos-arm64
# The binary is ad-hoc signed, not notarized, so macOS quarantines it on download.
# Clear the quarantine flag once:
xattr -d com.apple.quarantine maic
./maic --version
# then move it onto your PATH, e.g.:
mv maic ~/.local/bin/
```

Verify the download against the published `.sha256` if you like:

```
shasum -a 256 -c maic-<version>-macos-arm64.tar.gz.sha256
```

## Build from source

For hacking on maic, or if you'd rather build locally than download a release:

```
./build.sh                # builds release, installs to ~/.local/bin/maic
# or choose a location:
PREFIX=/usr/local/bin ./build.sh
```

Or just build in place:

```
swift build -c release
.build/release/maic <your request>
```

## Usage

```
maic <what you want to do>          suggest the command
maic --init zsh                     print the zsh integration (for ~/.zshrc)
maic -h                             help
```

## Shell integration (zsh)

maic never runs anything on its own. Instead it hands you the command to run,
edit, or throw away. The `install.sh` one-liner wires this into your `~/.zshrc`
automatically; from a source build, add it yourself:

```
eval "$(maic --init zsh)"
```

Then `maic <task>` places the suggested command on your next prompt, editable and
cursor-ready. Press Enter to run it (it enters your shell history normally), tweak
it first, or Ctrl-C to discard.

Why a shell function rather than doing it all in the binary? A child process can't
type into its parent shell's line editor — so the command is handed back to zsh
(via `print -z`), which is also what makes it land in your history and lets `cd`
or `export` actually stick.

Skip the automatic setup with `MAIC_NO_SHELL_INIT=1` when installing. To remove
the integration later, delete the block between the `# >>> maic shell integration >>>`
and `# <<< maic shell integration <<<` markers in your `~/.zshrc`. Without the integration (or in a pipe, `$(…)`, or a
non-interactive shell) `maic` simply prints the command, so `x=$(maic …)` still works.
