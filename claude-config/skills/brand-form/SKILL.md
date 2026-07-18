---
name: brand-form
description: Fill out a brand's creator/collab application form (Google Forms, Typeform, etc.) using real channel data. Use when Justin pastes a form link from a brand that replied to a sample request — "help me fill this out", "brand sent me a form", "collab form", "creator application". Scrapes the real questions, pulls verified YouTube numbers, and drafts every answer with nothing invented.
---

# Brand collab form filler

A brand replied to a sample request and sent an application form. Turn the form link
into a copy-paste answer sheet built on **verified** numbers.

## The one rule that matters

**Every factual answer must trace to a real source.** Subscriber counts, average views,
"do you make X content" — these are screening questions, and a brand that ships a sample
on an inflated number and gets a 4-view video is a brand that never works with us again.
The reach is what it is. The job is to find the *true* strongest angle, not a flattering
one. If the honest answer is weak, say so to Justin and let him decide — never quietly
round it up.

Never invent: shipping address, phone number, or any number you could not pull.
Leave those as `[NEED FROM JUSTIN]` and list them at the top of the answer sheet.

## STEP 1 — scrape the real questions

Do not eyeball the form in a browser. Google Forms embeds every question in a JS blob:

```bash
curl -sL "<form-url>" -o /tmp/form.html
grep -o 'FB_PUBLIC_LOAD_DATA_ = .*' /tmp/form.html | head -c 8000
```

Read the structure: each question is `[id, "Question text", null, TYPE, [[...options...]]]`.
TYPE: `0`=short text, `1`=paragraph, `2`=multiple choice (pick one), `4`=checkboxes (pick many).
For multiple choice / checkboxes the exact option strings are in the nested array — **quote
them verbatim** in the answer sheet so Justin just clicks, no interpretation.

Not a Google Form (Typeform/Jotform/Airtable)? Fall back to WebFetch, then the browser MCP
(`mcp__winchrome__navigate` + `snapshot`) if it's fully JS-rendered.

## STEP 2 — pull the real numbers

Channel IDs live in `/opt/relay/youtube.py` (`commquest`, `jdubb`, `dubb_outdoors`, `everyday`).

```
mcp__youtube-analytics__channel_analytics(channel="cq", start_date=..., end_date=...)
```
Gives views, watch time, subs gained/lost, traffic sources for a window. **Analytics API —
separate quota, usually works.**

`list_videos` / `top_videos` hit the **Data API quota, which is routinely exhausted** (see
the Shorts-via-OmniSocials memory). When they 403, scrape the public channel page instead:

```bash
curl -sL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36" \
  "https://www.youtube.com/channel/<ID>" > /tmp/ch.html
grep -oE '.{90}subscribers' /tmp/ch.html | head -6   # context disambiguates OUR channel from sidebar channels
grep -oE '\{"content":"[0-9.,KM]+ (views|videos)"' /tmp/ch.html | head -6
```

⚠️ The bare `grep -oE '[0-9.,KM]+ subscribers'` returns **recommended sidebar channels too**.
Always grep with leading context and match the handle (`@Comm_Quest`) before believing a number.

**Average views per video is the trap.** Channel-total views ÷ 90 days looks great and means
nothing when the catalog is thousands of evergreen videos living on search. Get *recent
per-upload* views from the channel page grid (`{"content":"N views"}`) — that is what the brand
is actually asking about, and it is usually far lower than the channel total implies.

## STEP 3 — pick the right channel (ask Justin)

One channel, one topic — per `ventures/CLAUDE.md`, we do **not** cross-post. The channel with
the biggest audience is often not the channel the product belongs on. When those two differ,
that is a real decision and it is **Justin's**, not yours: present both with their true numbers
and a recommendation, then wait.

## STEP 4 — write the answer sheet

Write to the scratchpad as markdown, in **form order**, each question with:
- the question verbatim
- the answer, ready to paste (for choice questions, the exact option text to click)
- a one-line `why:` for anything a human might second-guess

Head the file with `[NEED FROM JUSTIN]` items. End with the honest-read section: what this
application's real weaknesses are and what genuinely strongest angle the free-text fields lean on.

Free-text fields ("anything else you'd like us to know?") are where a modest channel wins or
loses. Lead with a true, specific, verifiable asset — evergreen search traffic, a storefront,
turnaround speed — never adjectives.
