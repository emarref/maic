import Foundation
import FoundationModels
import MaicCore

// `maic` — a tiny local interface to the on-device model shipped with macOS.
// Describe a task in plain English; get back a single macOS-specific shell command.
//
//   maic list files in this dir sorted by size, largest first
//
// With the zsh integration enabled (`eval "$(maic --init zsh)"`), the command is
// placed on your prompt — editable, cursor-ready — instead of just printed, so you
// can run it (Enter), tweak it, or discard it (Ctrl-C). Nothing runs on its own.
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

        // `maic --init <shell>` prints the shell integration and exits. Handled
        // before anything else so it never reaches the model. A leading `--init`
        // is unambiguous — a plain-English task never starts with a `--` flag.
        if args.first == "--init" {
            printShellInit(for: args.count > 1 ? args[1] : "zsh")
        }

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
                // Deprecated no-op. maic no longer runs commands itself — the zsh
                // integration puts the command on your prompt to run or edit. The
                // flag is still swallowed so old muscle memory doesn't leak `-r`
                // into the task text, but we say so rather than change behaviour
                // silently.
                FileHandle.standardError.write(Data(
                    "maic: -r/--run is deprecated and no longer runs the command; enable the zsh integration to run it from your prompt (see --help)\n".utf8))
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
            command = cleanCommand(response.content)
        } catch {
            FileHandle.standardError.write(Data("maic: generation failed — \(error.localizedDescription)\n".utf8))
            exit(70) // EX_SOFTWARE
        }

        guard !command.isEmpty else {
            FileHandle.standardError.write(Data("maic: model returned nothing\n".utf8))
            exit(70)
        }

        // Print the command. When invoked through the zsh function the command is
        // captured and placed on the prompt; run bare, it's just printed.
        print(command)
    }

    /// Emit shell integration for the named shell, then exit. Only zsh is supported.
    static func printShellInit(for shell: String) -> Never {
        switch shell {
        case "zsh":
            print(zshShellInit)
            exit(0)
        default:
            FileHandle.standardError.write(Data("maic: --init supports only 'zsh' (got '\(shell)')\n".utf8))
            exit(64) // EX_USAGE
        }
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

        With the zsh integration enabled, the suggested command is placed on your
        prompt — press Enter to run it, edit it first, or Ctrl-C to discard.
        Enable it once by adding this to your ~/.zshrc:

          eval "$(maic --init zsh)"

        OPTIONS:
          --init zsh    print the zsh shell integration (for eval in ~/.zshrc)
          -v, --version print the version and exit
          -h, --help    show this help

        EXAMPLES:
          maic list files sorted by size, largest first
          maic show my local IP address
          maic flush the DNS cache
        """
        print(usage)
    }
}
