// The release version, reported by `maic --version`.
//
// Local/dev builds report "dev". The release workflow
// (.github/workflows/release.yml) overwrites this file with the pushed tag
// before building, so shipped binaries report their real version.
let maicVersion = "dev"
