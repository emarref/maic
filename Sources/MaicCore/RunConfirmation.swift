import Foundation

/// What to do with the user's answer at the `-r` confirmation prompt.
public enum RunConfirmation: Equatable {
    case run
    case edit
    case abort
}

/// Interpret the answer typed at the `-r` prompt.
///
/// Pressing Enter (empty input) defaults to running; `y`/`yes` run;
/// `e`/`edit` edits first; `n`/`no` and anything unrecognised decline
/// (so a stray keystroke never runs a command by accident).
/// Case-insensitive and whitespace-tolerant.
public func runConfirmation(for rawAnswer: String) -> RunConfirmation {
    switch rawAnswer.trimmingCharacters(in: .whitespaces).lowercased() {
    case "", "y", "yes":
        return .run
    case "e", "edit":
        return .edit
    default:
        return .abort
    }
}
