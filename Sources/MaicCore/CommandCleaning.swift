import Foundation

/// Strip anything the model may have wrapped the command in despite instructions:
/// fenced code blocks, a stray single-backtick wrap, or a leading shell prompt
/// (`$ ` / `% `). Returns the bare command, trimmed of surrounding whitespace.
public func cleanCommand(_ raw: String) -> String {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    // Remove a fenced code block if present.
    if text.hasPrefix("```") {
        var lines = text.components(separatedBy: "\n")
        lines.removeFirst() // opening fence (possibly with a language tag)
        if let last = lines.last, last.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            lines.removeLast()
        }
        text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Strip a stray single-backtick wrap or leading shell prompt.
    if text.hasPrefix("`") && text.hasSuffix("`") && text.count > 1 {
        text = String(text.dropFirst().dropLast())
    }
    for prefix in ["$ ", "% "] where text.hasPrefix(prefix) {
        text = String(text.dropFirst(prefix.count))
    }

    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}
