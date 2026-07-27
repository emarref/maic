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
func check(_ input: String, _ expected: RunConfirmation, _ label: String) {
    let got = runConfirmation(for: input)
    if got == expected {
        print("ok   - \(label)")
    } else {
        print("FAIL - \(label): runConfirmation(\"\(input)\") == \(got), expected \(expected)")
        failures += 1
    }
}

// Acceptance criteria for issue #1.
check("", .run, "empty input (Enter) defaults to run")
check("y", .run, "y runs")
check("yes", .run, "yes runs")
check("n", .abort, "n aborts")
check("no", .abort, "no aborts")
check("e", .edit, "e edits")
check("edit", .edit, "edit edits")
check("maybe", .abort, "unrecognised input aborts")
check("q", .abort, "unrecognised input aborts")

// Case-insensitive and whitespace-tolerant.
check("Y", .run, "uppercase Y runs")
check("YES", .run, "uppercase YES runs")
check("  ", .run, "whitespace-only == empty == run")
check(" no ", .abort, "surrounding whitespace tolerated for no")
check("Edit", .edit, "mixed-case Edit edits")

print("")
if failures > 0 {
    print("\(failures) test(s) FAILED")
    exit(1)
}
print("all tests passed")
