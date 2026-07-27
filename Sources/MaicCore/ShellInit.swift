import Foundation

/// The zsh shell integration for maic, emitted by `maic --init zsh`.
///
/// A child process can't type into its parent shell's line editor, so the
/// "put the command on my prompt" behaviour has to live in the shell itself.
/// This function shadows the binary: it asks the binary for a command, then
/// uses zsh's buffer stack (`print -z`) to place that command on the next
/// prompt — editable, cursor-ready, nothing run until the user presses Enter.
///
/// Users wire it in with `eval "$(maic --init zsh)"` in their `~/.zshrc`.
///
/// A raw string literal keeps the shell's `$`, backticks and quotes verbatim.
public let zshShellInit: String = #"""
# maic shell integration (zsh). Enable with:  eval "$(maic --init zsh)"
maic() {
  emulate -L zsh
  local __maic_cmd
  __maic_cmd="$(command maic "$@")" || return
  [[ -n $__maic_cmd ]] || return
  # On an interactive prompt, drop the command onto the line editor so the user
  # can edit or run it. Otherwise (piped, captured in $(...), non-interactive)
  # just print it so `x=$(maic ...)` and pipelines keep working.
  if [[ -o interactive && -t 1 ]]; then
    print -rz -- "$__maic_cmd"
  else
    print -r -- "$__maic_cmd"
  fi
}
"""#
