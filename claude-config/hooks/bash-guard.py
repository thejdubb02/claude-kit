#!/usr/bin/env python3
"""PreToolUse guard for Bash.

Auto-approves Bash commands unless they contain a destructive verb, so the
compound/scripted one-liners Claude actually writes (pipes, && chains, for
loops, python heredocs) stop prompting. Anything that mutates system state,
deletes, force-pushes, or restarts a service still asks.

Threat model: catching MISTAKES, not defeating an adversary. A determined
process could obfuscate past these patterns; that is not what this is for.

Decisions:
  allow -> runs with no prompt
  ask   -> falls through to the normal permission prompt (never auto-denies)

Install: settings.json -> hooks.PreToolUse matcher "Bash".
Log:     /root/.claude/hooks/bash-guard.log (what it allowed vs. asked)
"""
import json
import re
import sys
from datetime import datetime

LOG = "/root/.claude/hooks/bash-guard.log"

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


# Anything matching these ASKS. Ordered roughly by blast radius.
DANGEROUS = [
    # catastrophic / disk
    (r"\brm\s+(-\w+\s+)*-\w*[rf]", "recursive/forced delete"),
    (r"\bmkfs\b|\bdd\s+if=|>\s*/dev/(sd|nvme|vd)", "disk write"),
    (r">\s*/dev/null\s*;\s*rm", "delete after redirect"),
    (r"\bshred\b|\bwipefs\b", "disk wipe"),
    # python/node destructive calls inside heredocs
    (r"shutil\.rmtree|os\.remove|os\.unlink|os\.rmdir|Path\([^)]*\)\.unlink", "python delete"),
    (r"\bsubprocess\b|\bos\.system\b|\bexec\(|\beval\(", "python shells out"),
    # service + container state
    (r"\bsystemctl\s+(restart|stop|start|disable|enable|mask|daemon-reload)", "systemd state change"),
    (r"\bservice\s+\S+\s+(stop|start|restart)", "service state change"),
    (r"\bdocker\s+(rm|rmi|stop|kill|restart|run|prune|create)", "docker state change"),
    # `docker exec` is judged by its PAYLOAD, not the verb: `occ app:list` is a
    # read-only inspection, `occ app:install` is not. Only the mutating ones ask.
    (r"\bdocker\s+exec\b(?=[^|;&]*\b("
     r"install|uninstall|remove|delete|disable|enable|upgrade|migrate|reset|repair|"
     r"drop|truncate|insert\s|update\s|alter\s|purge|prune|restore|import|"
     r"maintenance:|db:|user:add|user:delete|config:.*:set|occ\s+\S+:set"
     r")\b)", "docker exec runs a mutating command"),
    (r"\bdocker[- ]compose\s+(down|up|restart|rm)", "compose state change"),
    (r"\bcaprover\b", "caprover deploy"),
    # git history / remote
    (r"\bgit\s+push", "git push"),
    (r"\bgit\s+reset\s+--hard|\bgit\s+clean\s+-\w*[fd]", "git destructive"),
    (r"\bgit\s+rebase|\bgit\s+filter-branch", "git history rewrite"),
    # packages / system config
    (r"\b(apt|apt-get|yum|dnf|snap)\s+(install|remove|purge|upgrade)", "package change"),
    (r"\b(pip|pip3|npm|yarn|pnpm|bun)\s+(install|uninstall|add|remove)", "dependency change"),
    (r"\bsysctl\s+-w|\bsysctl\s+-p", "kernel param change"),
    (r"\b(useradd|userdel|usermod|passwd|chpasswd)\b", "user/account change"),
    (r"\b(iptables|ufw|nft)\b", "firewall change"),
    (r"\bcrontab\s+(-r|-)\s*$|\bcrontab\s+\S+$", "crontab replace"),
    (r"\b(reboot|shutdown|halt|poweroff|init\s+[06])\b", "host power state"),
    (r"\bkill(all)?\b|\bpkill\b", "process kill"),
    # writes to system paths
    (r"(>|>>|tee\s+(-a\s+)?)\s*/(etc|usr|boot|lib|sbin|bin|sys|proc)/", "write to system path"),
    (r"\bsed\s+-i\b.*\s/(etc|usr|boot|lib)/", "in-place edit of system file"),
    (r"\bchown\b.*\s/(etc|usr|boot|lib|opt)/|\bchmod\b.*\s/(etc|usr|boot|lib)/", "perms on system path"),
    (r"\brm\b.*/(etc|usr|boot|lib|sbin|bin)/", "delete from system path"),
    # network mutations
    (r"\bcurl\b[^|;&]*-X\s*(POST|PUT|DELETE|PATCH)", "mutating HTTP request"),
    (r"\bcurl\b[^|;&]*(-d|--data)\b", "HTTP request with body"),
    # secrets
    (r"/\.ssh/|id_rsa|id_ed25519|\.env\b.*>|authorized_keys", "credential file"),
    (r"\bbw\s+(delete|create|edit)|\bvaultwarden\b.*\b(delete|purge)", "secret store change"),
]

COMPILED = [(re.compile(p, re.I), why) for p, why in DANGEROUS]


# Rules Justin explicitly approved via `bash-guard-review --apply`. These override
# DANGEROUS — but only because a human ran --apply. The hook NEVER adds to this file.
LEARNED = "/root/.claude/hooks/learned-allow.json"

# The floor. Never auto-allowed, no matter what is in learned-allow.json.
NEVER = [re.compile(p, re.I) for p in [
    r"rm\s+-\w*[rf]\w*\s+/(\s|$|\*)", r"\bmkfs\b", r"\bdd\s+if=", r"\bshred\b",
    r"git\s+push\s+--force", r"git\s+reset\s+--hard",
    r"\b(reboot|shutdown|halt|poweroff)\b", r"\b(useradd|userdel|passwd)\b",
    r"/\.ssh/|id_rsa|id_ed25519|authorized_keys", r"\biptables\s+-F",
]]


def _normalize(cmd):
    c = re.sub(r"\s+", " ", cmd.strip())
    # NOTE: quoted payloads are deliberately NOT collapsed. Stripping them would let
    # a learned pattern like `docker exec x sh -c …` auto-allow ANY payload, including
    # a destructive one. Patterns stay specific to what was actually approved.
    c = re.sub(r"\b[0-9a-f]{7,40}\b", "…", c)
    c = re.sub(r"\b\d+\b", "N", c)
    return c[:90]


def _learned():
    try:
        return {p["pattern"] for p in json.load(open(LEARNED))["patterns"]}
    except Exception:
        return set()


def decide(cmd: str):
    # The floor always wins, even over learned rules.
    for rx in NEVER:
        if rx.search(cmd):
            return "ask", "never-auto-allowed"

    for rx, why in COMPILED:
        m = rx.search(cmd)
        if m:
            # Did Justin explicitly teach us this one is fine?
            if _normalize(cmd) in _learned():
                return "allow", f"learned (was: {why})"
            return "ask", f"{why} ({m.group(0)[:40].strip()})"
    return "allow", "no destructive verb found"


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # malformed -> fall through to normal prompting

    if payload.get("tool_name") != "Bash":
        sys.exit(0)

    cmd = (payload.get("tool_input") or {}).get("command", "")
    if not cmd.strip():
        sys.exit(0)

    decision, reason = decide(cmd)

    try:
        with open(LOG, "a") as fh:
            fh.write(f"{datetime.now():%F %T} {decision:5s} {reason:44s} :: {logline(cmd)[:300]}\n")
    except Exception:
        pass

    if decision == "allow":
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "permissionDecisionReason": f"bash-guard: {reason}",
            }
        }))
    # "ask" -> emit nothing, let the normal permission flow run
    sys.exit(0)


if __name__ == "__main__":
    main()
