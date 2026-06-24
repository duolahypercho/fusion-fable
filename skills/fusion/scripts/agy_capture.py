#!/usr/bin/env python3
"""Windows-native capture for the Antigravity Gemini CLI (`agy`).

`agy -p` renders its answer to the Windows console (ConPTY), so piped stdout is
empty and there is no PTY/jq path on this box. But agy writes every turn to a
per-conversation transcript on disk. This helper runs a single prompt in an
isolated workspace directory (so the conversation is fresh and unambiguous),
waits for the model's response to land in that transcript, prints it to stdout,
and cleans up the lingering agy process.

Usage:
    agy_capture.py "<prompt>"            # prompt as arg
    echo "<prompt>" | agy_capture.py -   # prompt on stdin

Exit codes: 0 = response captured (printed to stdout); non-zero = failure.
"""
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# agy answers routinely contain non-Latin-1 glyphs (≤, ≥, –, ✓, math symbols). On Windows,
# Python defaults stdout to cp1252 when redirected to a pipe/file, which raises
# UnicodeEncodeError mid-write and leaves the output empty. Force UTF-8.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

HOME = Path(os.path.expanduser("~"))
CLI = HOME / ".gemini" / "antigravity-cli"
LCJ = CLI / "cache" / "last_conversations.json"
BRAIN = CLI / "brain"
AGY = HOME / "AppData" / "Local" / "agy" / "bin" / "agy.exe"

# A MODEL turn carrying the final text answer.
MODEL_TYPES = {"PLANNER_RESPONSE", "ASSISTANT_RESPONSE", "MODEL_RESPONSE", "RESPONSE"}

POLL_SECONDS = float(os.environ.get("AGY_POLL_SECONDS", "300"))
QUIET_SECONDS = float(os.environ.get("AGY_QUIET_SECONDS", "8"))  # stop once transcript stops growing


def transcript_for(conv_id: str) -> Path:
    return BRAIN / conv_id / ".system_generated" / "logs" / "transcript.jsonl"


def conv_id_for(ws: str):
    try:
        m = json.loads(LCJ.read_text(encoding="utf-8"))
    except Exception:
        return None
    # keys are stored with Windows backslashes
    for k, v in m.items():
        if os.path.normcase(os.path.normpath(k)) == os.path.normcase(os.path.normpath(ws)):
            return v
    return None


def model_text(tpath: Path) -> str:
    if not tpath.exists():
        return ""
    out = []
    for ln in tpath.read_text(encoding="utf-8", errors="replace").splitlines():
        ln = ln.strip()
        if not ln:
            continue
        try:
            o = json.loads(ln)
        except Exception:
            continue
        if o.get("source") == "MODEL" and (o.get("type") in MODEL_TYPES):
            c = o.get("content")
            if c:
                out.append(c)
    return "\n".join(out).strip()


def main() -> int:
    if len(sys.argv) < 2:
        sys.stderr.write("usage: agy_capture.py '<prompt>' | echo p | agy_capture.py -\n")
        return 2
    prompt = sys.stdin.read() if sys.argv[1] == "-" else sys.argv[1]
    prompt = prompt.strip()
    if not prompt:
        sys.stderr.write("empty prompt\n")
        return 2

    ws = tempfile.mkdtemp(prefix="fusion_agy_")
    cmd = [str(AGY), "-p", prompt,
           "--dangerously-skip-permissions",
           "--print-timeout", f"{int(POLL_SECONDS)}s"]
    model = os.environ.get("AGY_MODEL", "").strip()
    if model:
        cmd += ["--model", model]
    proc = subprocess.Popen(
        cmd,
        cwd=ws,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
    )

    deadline = time.time() + POLL_SECONDS
    conv_id = None
    last_text = ""
    last_change = None
    while time.time() < deadline:
        if conv_id is None:
            conv_id = conv_id_for(ws)
        if conv_id:
            txt = model_text(transcript_for(conv_id))
            if txt and txt != last_text:
                last_text = txt
                last_change = time.time()
            # response present and transcript quiet for QUIET_SECONDS => done
            if last_text and last_change and (time.time() - last_change) > QUIET_SECONDS:
                break
        if proc.poll() is not None and last_text:
            break
        time.sleep(1)

    # tear down the lingering agy language server
    try:
        proc.terminate()
    except Exception:
        pass
    try:
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    if not last_text:
        sys.stderr.write(f"agy_capture: no MODEL response captured (ws={ws}, conv={conv_id})\n")
        return 1
    sys.stdout.write(last_text + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
