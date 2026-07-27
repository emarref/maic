import Foundation
import MaicCore

// Test harness for MaicCore. Run with `swift run maicTests`.
// Exits non-zero if any case fails, so CI can gate on it.
//
// A plain executable is used instead of a `testTarget` because `swift test`
// requires a full Xcode install to execute; this runs under the Command Line
// Tools toolchain too.

var failures = 0

@MainActor
func expect(_ got: String, _ expected: String, _ label: String) {
    if got == expected {
        print("ok   - \(label)")
    } else {
        print("FAIL - \(label): got \"\(got)\", expected \"\(expected)\"")
        failures += 1
    }
}

@MainActor
func expect(_ cond: Bool, _ label: String) {
    if cond {
        print("ok   - \(label)")
    } else {
        print("FAIL - \(label)")
        failures += 1
    }
}

// --- cleanCommand: the model's output is stripped back to a bare command ---

expect(cleanCommand("ls -laS"), "ls -laS", "plain command is unchanged")
expect(cleanCommand("  ls -laS  "), "ls -laS", "surrounding whitespace trimmed")
expect(cleanCommand("$ ls -laS"), "ls -laS", "leading '$ ' prompt stripped")
expect(cleanCommand("% ls -laS"), "ls -laS", "leading '% ' prompt stripped")
expect(cleanCommand("`ls -laS`"), "ls -laS", "single-backtick wrap stripped")
expect(cleanCommand("```\nls -laS\n```"), "ls -laS", "bare fenced block stripped")
expect(cleanCommand("```sh\nls -laS\n```"), "ls -laS", "language-tagged fence stripped")
expect(cleanCommand("```bash\nfind . -type f -mtime +1\n```"),
       "find . -type f -mtime +1", "fence around a realistic command")
expect(cleanCommand(""), "", "empty stays empty")
expect(cleanCommand("   "), "", "whitespace-only collapses to empty")
// A lone backtick is not a wrap and must survive (dropFirst/dropLast guard).
expect(cleanCommand("`"), "`", "a lone backtick is left alone")

// --- zshShellInit: the integration emitted by `maic --init zsh` -----------

expect(zshShellInit.contains("maic() {"), "init defines a maic() function")
expect(zshShellInit.contains("command maic"), "init calls the real binary via `command maic`")
expect(zshShellInit.contains("print -rz"), "init pushes the command onto the zle buffer")
expect(zshShellInit.contains("-t 1"), "init guards the interactive path on a TTY")

print("")
if failures > 0 {
    print("\(failures) test(s) FAILED")
    exit(1)
}
print("all tests passed")
