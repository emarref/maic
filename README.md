# maic

*Puts the AI in mac.*

A tiny local CLI that turns a plain-English description into the right **macOS-specific**
shell command, using the on-device model shipped with macOS (Apple's
[FoundationModels](https://developer.apple.com/documentation/foundationmodels) framework).

Everything runs on-device — no network, no API key, nothing leaves your Mac.

```
$ maic list files in this dir sorted by size, largest first
ls -laS

$ maic show my primary local IP address
ipconfig getifaddr en0

$ maic -r flush the DNS cache
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
Run this? [y/N/e to edit]
```

Because it's told to assume the BSD userland that ships with macOS, it prefers
`stat -f`, `sed -i ''`, `pbcopy`, `mdfind`, `networksetup`, etc. — not GNU/Linux flags.

## Requirements

- macOS 26 or later on Apple-Intelligence-capable hardware (Apple silicon).
- **Apple Intelligence must be turned on:** System Settings → Apple Intelligence & Siri →
  turn on Apple Intelligence. The model downloads in the background the first time;
  until it's ready `maic` will tell you so.
- Xcode Command Line Tools (`xcode-select --install`) — full Xcode is not required.

## Download a release

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

## Build & install

```
./install.sh              # builds release, installs to ~/.local/bin/maic
# or choose a location:
PREFIX=/usr/local/bin ./install.sh
```

Or just build in place:

```
swift build -c release
.build/release/maic <your request>
```

## Usage

```
maic <what you want to do>          print the command
maic -r <what you want to do>       print it, then confirm before running
maic -h                             help
```

The `-r`/`--run` flow always confirms first (`y` to run, `e` to edit, anything else
to abort) — the model can be wrong or suggest something destructive, so nothing runs
without your say-so.
