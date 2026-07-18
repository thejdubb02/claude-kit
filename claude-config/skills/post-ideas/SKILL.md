---
name: post-ideas
description: Use this skill whenever Justin asks for social media post ideas, build-in-public content, "what should I post about", "draft me a post", "make content for the next [day/week/two weeks]", or anything related to LinkedIn / X / Threads content. Surfaces recent work from git activity + CHANGELOGs, maps candidates to voice-file archetypes, drafts in Justin's voice, and pushes to OmniSocials as drafts or scheduled posts.
---

# post-ideas

End-to-end workflow for Justin's build-in-public content on LinkedIn, X, and Threads.

## Required reading every invocation

Before doing anything else, read these two files in full:

1. `/root/wsg-voice/voice.md` — canonical voice spec. Anti-AI rules, banned vocabulary, length targets, hook patterns, output contract. Do not paraphrase or compress these rules at runtime.
2. `/root/.claude/projects/-root/memory/feedback_no_twitch_retrospectives.md` — hard rule against Twitch-anchored posts.

## Step 1 — Research recent work

Pull the last 14 days of activity from these sources in parallel:

```bash
# Infra audit (single best source — CHANGELOG-grade entries)
cd /root/wsg-infra-audit && git log --since="14 days ago" --pretty=format:"%ad %s" --date=short
head -150 /root/wsg-infra-audit/CHANGELOG.md

# Per-project commits
for repo in /root/dealophant /root/my-glp-shot /root/.openclaw/workspace/daily/wsg-cp; do
  echo "=== $repo ==="
  git -C "$repo" log --since="14 days ago" --pretty=format:"%ad %s" --date=short 2>/dev/null
done

# Per-client recent work
for d in /root/wsg-client-projects/*/; do
  echo "=== $d ==="
  git -C "$d" log --since="14 days ago" --pretty=format:"%ad %s" --date=short 2>/dev/null | head -10
done

# Project state for context on current focus
head -120 /root/.claude/projects/-root/memory/PROJECT_STATE.md
```

If the omnisocials MCP is connected, also call `mcp__omnisocials__list_posts` (status=scheduled, then status=published) to avoid pitching topics already queued.

## Step 2 — Cluster and map to archetypes

From the raw activity, identify 5-8 distinct post-worthy topics. Each must be anchored to a real artifact, number, or specific event. Map each to the rotation:

| Day | Archetype |
|---|---|
| Mon | Number Post |
| Tue | Ship Post |
| Wed | Operator-Not-Dev Take OR Reframe |
| Thu | Forward commitment / present-tense operator philosophy / competitive moat (Twitch Lesson is retired) |
| Fri | Loss Post OR Behind-the-Scenes OR Client Win |
| Sun | Question Post (low-competition slot, optional) |

Client Wins: only use a real client name if Justin confirms permission. Otherwise generic ("a client", "a contractor in California").

## Step 3 — Present slate, get confirmation

Show the candidate slate as a table or short list. For each candidate include:
- One-line summary
- Suggested archetype + day
- One sentence on why it works

Recommend a strongest pick or full week/two-week lineup. Wait for Justin to pick or edit before drafting.

## Step 4 — Draft (when Justin confirms)

Per voice.md output contract, generate three variants per topic:
- **Variant A** — most direct telling, LinkedIn long-form (1,000-1,800 chars)
- **Variant B** — different archetype angle on the same topic, LinkedIn long-form
- **Variant C** — X-native, under 280 chars

For Threads: clone the X version. Threads supports 500 chars and X copy fits cleanly.

Show all drafts with char counts. Wait for Justin to pick variants (or "push all").

## Step 5 — Push to OmniSocials

Channels: `679855_linkedin`, `679855_x`, `679855_threads`.

Use `mcp__omnisocials__create_post`. Schedule patterns Justin uses:
- **Default if no preference stated:** create as draft (no `scheduled_at`)
- **Common explicit pattern:** Mon-Fri at 4am Pacific (11:00 UTC in PDT, 12:00 UTC in PST)
- **Common variant:** random between 3:00-4:15am Pacific (10:00-11:15 UTC PDT, 11:00-12:15 UTC PST) — pick one time per channel per day

After pushing, return a table of post IDs + scheduled times + OmniSocials URLs.

## Step 6 — LinkedIn tag follow-up

For LinkedIn drafts that mention specific products / companies / people that should be `@` mentions: the API publishes them as plain text. Remind Justin to open each LinkedIn draft in OmniSocials' composer once and retype the `@` to convert plain text into real entity-mention chips. X and Threads `@` handles auto-link from plain text and don't need this.

## Hard rules

- No em dashes anywhere — use commas, periods, or rewrite the sentence
- No banned vocabulary: delve, leverage, unlock, harness, robust, seamless, streamline, transform (as verb), elevate, humbled, blessed, game-changer, no-brainer, 10x, "let that sink in"
- No "I noticed your post" surveillance language
- No fake or made-up quotes / dialogue
- No inflated percentages without absolute numbers
- No Twitch-anchored posts (see feedback memory)
- No filler closers; closes should be a specific question, a forward commitment, or a concrete punch line
- Every post anchored to a real artifact, number, or specific event from the actual work

## Voice anchoring check

Before finalizing any draft, re-read it once asking: "could a human who actually shipped this thing have written this." If it sounds even slightly AI-flavored — parallel three-bullet structures, generic insight after generic insight, motivational closer — regenerate from a different opening.
