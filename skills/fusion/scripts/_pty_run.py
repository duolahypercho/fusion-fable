#!/usr/bin/env python3
"""_pty_run.py — run a command attached to a fresh pseudo-terminal, copy its output to stdout.

Why this exists: agy bug #76 emits empty stdout when its stdout is not a TTY. The usual fix,
`script -q /dev/null <cmd>`, calls tcgetattr() on fd 0 to clone the terminal settings — which
FAILS with "Operation not supported on socket" when the orchestrator itself runs in a socket
(cmux / headless Claude Code), aborting before the command even launches. unbuffer / pty.spawn()
hit the same wall (they put the parent's stdin in raw mode).

pty.fork() instead gives the *child* a brand-new controlling pty and never touches the parent's
fd 0 termios, so it survives a socket stdin. The parent just reads the pty master and writes the
bytes to its own stdout (writing to a socket is fine). ANSI/control-byte cleanup is left to the
caller's sed|tr pipeline.

Usage: python3 _pty_run.py <cmd> [args...]
Exit code = the command's exit code (127 if it could not be exec'd).
"""
import os
import pty
import sys


def main() -> int:
    argv = sys.argv[1:]
    if not argv:
        sys.stderr.write("_pty_run.py: no command given\n")
        return 2

    pid, master = pty.fork()
    if pid == 0:
        # Child: stdin/stdout/stderr are already wired to the new pty slave.
        try:
            os.execvp(argv[0], argv)
        except OSError as e:
            sys.stderr.write(f"_pty_run.py: cannot exec {argv[0]}: {e}\n")
            os._exit(127)

    # Parent: stream the pty output to our real stdout until the slave closes.
    while True:
        try:
            data = os.read(master, 65536)
        except OSError:
            break  # EIO on master after the child exits
        if not data:
            break
        try:
            os.write(1, data)
        except OSError:
            break

    try:
        os.close(master)
    except OSError:
        pass

    _, status = os.waitpid(pid, 0)
    if hasattr(os, "waitstatus_to_exitcode"):
        code = os.waitstatus_to_exitcode(status)
        return abs(code)
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    return 1


if __name__ == "__main__":
    sys.exit(main())
