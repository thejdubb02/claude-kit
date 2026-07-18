#!/usr/bin/env python3
"""PostToolUse logger — records Bash commands that ACTUALLY RAN.

A command only reaches PostToolUse if it was permitted. Correlating this against
bash-guard's "ask" decisions gives us the false positives: commands the guard
stopped that Justin approved anyway. Those are the candidates for learning.

Writes: /root/.claude/hooks/bash-executed.log
Review: bash-guard-review  (proposes patterns; Justin approves; never auto-applies)
"""
import json
import sys
from datetime import datetime

LOG = "/root/.claude/hooks/bash-executed.log"
import re

# Redact secrets before anything is written to disk.
SECRET_PATTERNS = [
    (re.compile(r"(sshpass\s+-p\s+)(['\"]?)([^'\"\s]+)\2"), r"\1\2«redacted»\2"),
    (re.compile(r"(--password[= ])(\S+)"), r"\1«redacted»"),
    (re.compile(r"((?:api[_-]?key|token|secret|passwd|password)\s*[=:]\s*)(['\"]?)([^'\"\s]{6,})\2", re.I), r"\1\2«redacted»\2"),
    (re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{20,})"), "«redacted»"),
    (re.compile(r"\b(sk-[A-Za-z0-9\-_]{20,})"), "«redacted»"),
    (re.compile(r"\b(whsec_[A-Za-z0-9]{10,})"), "«redacted»"),
]


def scrub(s):
    for rx, repl in SECRET_PATTERNS:
        s = rx.sub(repl, s)
    return s


def logline(s):
    """One log entry = one line. Escape newlines so heredocs don't corrupt the file."""
    return scrub(s).replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t")


try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)

if payload.get("tool_name") != "Bash":
    sys.exit(0)

cmd = (payload.get("tool_input") or {}).get("command", "")
if not cmd.strip():
    sys.exit(0)

try:
    with open(LOG, "a") as fh:
        fh.write(f"{datetime.now():%F %T}\t{logline(cmd)[:600]}\n")
except Exception:
    pass

sys.exit(0)
