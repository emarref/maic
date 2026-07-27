import Foundation
import FoundationModels
import MaicCore

// `maic` — a tiny local interface to the on-device model shipped with macOS.
// Describe a task in plain English; get back a single macOS-specific shell command.
//
//   maic list files in this dir sorted by size, largest first
//   maic -r flush the dns cache          # -r prompts before running the command
//
// Nothing leaves the machine: this uses Apple's on-device FoundationModels.

@main
struct Maic {
    static let instructions = """
        You are a command-line assistant for macOS (Darwin / zsh). The user describes a \
        task in plain English. Reply with EXACTLY ONE shell command that accomplishes it \
        on a default macOS install, and nothing else.

        Rules:
        - Output the command only. No explanation, no commentary, no markdown code fences, \
          no leading `$` or `%`.
        - Assume the BSD userland that ships with macOS, not GNU/Linux. Prefer macOS-native \
          tools and flag styles: `stat -f`, `sed -i ''`, `sysctl`, `sw_vers`, `pbcopy`/`pbpaste`, \
          `mdfind`, `networksetup`, `scutil`, `dscacheutil`, `launchctl`, `diskutil`, `caffeinate`, \
          `open`, `defaults`. Do NOT assume GNU coreutils flags (`stat -c`, `sed -i` without '', \
          `date -d`) unless the user says they installed them.
        - If several steps are required, combine them into one line with pipes or `&&`.
        - If the task is genuinely impossible or nonsensical as a single command, output a \
          single `#` comment line explaining why in under 12 words.
        """

    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())

        var runAfter = false
        var remaining: [String] = []
        for arg in args {
            switch arg {
            case "-h", "--help":
                printUsage()
                exit(0)
            case "-v", "--version":
                print("maic \(maicVersion)")
                exit(0)
            case "-r", "--run":
                runAfter = true
            default:
                remaining.append(arg)
            }
        }
        args = remaining

        let query = args.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            printUsage()
            exit(64) // EX_USAGE
        }

        // Confirm the on-device model is usable before we try.
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            FileHandle.standardError.write(Data("maic: on-device model unavailable — \(describe(reason))\n".utf8))
            exit(69) // EX_UNAVAILABLE
        @unknown default:
            FileHandle.standardError.write(Data("maic: on-device model unavailable\n".utf8))
            exit(69)
        }

        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(temperature: 0.2)

        let command: String
        do {
            let response = try await session.respond(to: query, options: options)
            command = clean(response.content)
        } catch {
            FileHandle.standardError.write(Data("maic: generation failed — \(error.localizedDescription)\n".utf8))
            exit(70) // EX_SOFTWARE
        }

        guard !command.isEmpty else {
            FileHandle.standardError.write(Data("maic: model returned nothing\n".utf8))
            exit(70)
        }

        print(command)

        guard runAfter else { return }

        // A model can be wrong or dangerous, so we still confirm — but the
        // common case is "yes, run it", so Enter defaults to running.
        FileHandle.standardError.write(Data("Run this? [Y/n/e to edit] ".utf8))
        let answer = readLine(strippingNewline: true) ?? ""

        var toRun = command
        switch runConfirmation(for: answer) {
        case .run:
            break
        case .edit:
            FileHandle.standardError.write(Data("Edit command: ".utf8))
            let edited = readLine(strippingNewline: true)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !edited.isEmpty else { exit(0) }
            toRun = edited
        case .abort:
            exit(0)
        }

        exit(run(toRun))
    }

    /// Strip anything the model may have wrapped the command in despite instructions.
    static func clean(_ raw: String) -> String {
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

    static func run(_ command: String) -> Int32 {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-c", command]
        do {
            try process.run()
        } catch {
            FileHandle.standardError.write(Data("maic: failed to launch shell — \(error.localizedDescription)\n".utf8))
            return 126
        }
        process.waitUntilExit()
        return process.terminationStatus
    }

    static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "this device doesn't support Apple Intelligence"
        case .appleIntelligenceNotEnabled:
            return "turn on Apple Intelligence in System Settings"
        case .modelNotReady:
            return "the model is still downloading or warming up — try again shortly"
        @unknown default:
            return "unknown reason"
        }
    }

    static func printUsage() {
        let usage = """
        maic — get the right macOS shell command from a plain-English description.
               Runs entirely on-device via Apple's FoundationModels; nothing leaves your Mac.

        USAGE:
          maic <what you want to do>
          maic -r <what you want to do>     confirm, then run the command

        OPTIONS:
          -r, --run     after printing the command, confirm then run it
                        (prompt is [Y/n/e to edit]; Enter or y runs, n aborts, e edits first)
          -v, --version print the version and exit
          -h, --help    show this help

        EXAMPLES:
          maic list files sorted by size, largest first
          maic show my local IP address
          maic -r flush the DNS cache
        """
        print(usage)
    }
}
