---
name: explainer-animation
description: Autonomously produce a professional 30–60 s whimsical, hand-drawn paper-collage explainer animation in pure JavaScript (canvas + Web Audio) about what the current project does and how. Includes neural-TTS narration, a synthesised score and sound effects, a self-contained HTML player and an MP4 export. Use when the user asks for an explainer video, animated intro, promo or "what does this project do" animation, or invokes /explainer-animation. Honours a requested narration language (default English) and a token budget (default 10 USD).
---

# Explainer animation: pure-JS paper-collage video with narration

You are the whole studio: concept, script, voice, art, animation, music, sound
design, mix and export. The user is usually away, so work autonomously until the
job is done and verified. Quality is the goal, and cost is the constraint.

## Prerequisites

Check these first; if one is missing, stop and tell the user rather than working around it.

- **Linux x86_64** with **Node.js 18+ and npm**. `setup.sh` refuses anything else (no macOS or ARM).
- **apt-based distro** (Debian/Ubuntu) *if* headless Chrome is missing shared libs: `setup.sh`
  fetches them with `apt-get download` (no sudo). Its package map uses Ubuntu 24.04 (`t64`) names,
  with the older names tried as a fallback. Elsewhere, install the libs it reports yourself.
- **~400 MB disk** in the scratchpad (puppeteer, headless shell, ffmpeg-static).
- **Outbound network** to npm, `fonts.googleapis.com` / `fonts.gstatic.com`, and Microsoft's Edge
  read-aloud TTS endpoint (used by `msedge-tts`). That endpoint is **unofficial and unauthenticated**:
  it can rate-limit, change or disappear without notice. If `tts.mjs` fails after its retries,
  report it; don't silently switch to a paid service (see step 3, Narration).

## Inputs (infer; ask only if truly blocking)

- **Subject:** the current project. Learn it from `CLAUDE.md`/`AGENTS.md`/README and
  the top-level layout. Explain *what it does* and *how* (its real mechanisms), not
  marketing fluff. Every scene should map to a real subsystem.
- **Language:** English by default. If the user names a language, **all** speech and
  **all** on-screen text use that language. There is no mixed-language narration:
  - pick a native neural voice for that locale (`node tts.mjs --voices <locale>`);
  - write the script natively in that language, not translated word-for-word;
  - spell brand names and acronyms phonetically *for that voice* (e.g. "H N L trader",
    "R.S.I." from the reference build), and keep code identifiers off-screen or treat them as proper nouns;
  - make sure the embedded fonts cover every glyph (`SUBSET=latin-ext|cyrillic|greek|…`;
    for CJK use a font with full coverage and verify rendering in a screenshot).
- **Length:** 30–60 s (aim ~55 s). **Budget:** default 10 USD of tokens, or whatever the user says.
- **Output:** a directory inside the project, e.g. `demos/explainer/` (check for an existing
  `demos/`/`docs/` convention first). Don't commit unless asked.

## Budget discipline (this is what keeps it under 10 USD)

- Don't read the codebase broadly: `CLAUDE.md` + README are usually enough. Delegate
  any deeper exploration to a cheap subagent only if the docs are thin.
- Write the animation **in one large file write**, then iterate with targeted edits
  (python/sed replacements that assert the old string exists). Never re-read the whole file.
- Visual QA with **2×2 contact sheets** (`sheet.sh`): four frames per image read. Expect
  about 5–7 sheet reads in total. Crop to a region when checking a single detail.
- Run long jobs (the MP4 render takes ~7 min for 58 s on a 6 GiB VM) in the background,
  and don't poll with sleep. Restart a render only after batching all fixes.

## Pipeline

All scripts are in `scripts/` next to this file (`<skill>` below = this skill's directory).
Work in the session scratchpad and run every step from there; publish only the deliverables
into the project:

```bash
W=<scratchpad>/explainer; mkdir -p "$W" && cp <skill>/scripts/* "$W"/ && cd "$W"
```

1. **Toolchain** (no sudo): `./setup.sh "$W"`, then
   `export LD_LIBRARY_PATH=$W/libs/usr/lib/x86_64-linux-gnu`. This installs ffmpeg-static,
   msedge-tts and puppeteer, and unpacks any missing Chrome libs from `apt-get download`.
   `python3 -m venv` may not exist, so prefer npm packages. Never install into the project tree.
2. **Concept + script.** Use ~7 beats of one sentence each (~110–130 words total at 150 wpm).
   Beat 1 is title/hook, the middle beats are the mechanisms in pipeline order, and the last
   beat is a rhythmic recap plus the name. Give it a mascot (e.g. a cardboard robot) and a
   secondary character for any review or feedback idea. Put the lines in `lines.json`.
3. **Narration:** `VOICE=… RATE=-4% node tts.mjs lines.json` (Edge neural voices; the
   `*MultilingualNeural` voices are the most natural. English: `en-US-AndrewMultilingualNeural`
   (warm male) or `en-US-AvaMultilingualNeural`). Then `node cues.mjs` trims silence,
   loudness-normalises each line, and writes `cues.json` with absolute **per-word timestamps**.
   `cues.mjs` takes `START` (first line, default 1.6 s) and `GAP` (between lines, default 0.75 s):
   re-run it with different values until speech ends by ~55 s. Then `node assemble.mjs` →
   `narration.mp3` + `timeline.json`. The video length (`DUR`) is computed **once**, here: the first
   bar line after the last word (`FIN`) plus `TAIL` (default 3.3 s) for the finale. `build.mjs`
   and `render.mjs` read it from there, so never hardcode a duration anywhere else.
   **Paid TTS is opt-in only.** Use ElevenLabs, OpenAI or similar only if the user explicitly asked
   for it in this request, even if a key is lying around in the environment or `.env`. Don't read
   `.env` files to look for one. With paid TTS you need word timings from another source
   (per-line clips + proportional estimates are fine).
4. **Fonts:** `./fonts.sh "Caveat:wght@700" "Permanent+Marker" "Special+Elite" "Abril+Fatface" "Patrick+Hand"`
   (swap in families that cover your language).
5. **Animation source** (`src.html`): start from `reference/engine-example.html`. That file is the
   **hnl-trader** explainer ("The Little Trading Machine"): its title, copy, scenes, charts, recap
   chips and hardcoded scene times belong to that project. Don't reuse its story or imagery; keep
   the engine and write new scenes, timings and sound events for the new subject. Reusable parts:
   - geometry, `tornPoly`, `makeSprite` (torn paper + rim + grain + baked blurred shadow),
     `drawSprite` (boil jitter, lift shadow, `over` callback for local drawing), `ink`
     (double-pass wobbly stroke with `reveal` write-on, boils at 10 fps), `hand` (written-on
     text), `makeStamp`, the characters `robot`/`owl`, doodles, paper backgrounds,
     `drawFrame` (camera drift, shakes, torn-paper wipes, grain, flicker, vignette, fades);
   - audio: `I` instruments (pluck, glock, bass, kick, noise, block), `FX` (pop, swoosh, rip,
     scribble, thud, ding, chime, clink, boing, bloop, flutter, click, tapestop, sparkle, riser,
     cymbal), the time-shift wrapper (`SH`/`DEPTH`), `buildEvents`, `musicGainAt` ducking,
     `makeGraph`, realtime scheduler + seek, `__renderAudio` (OfflineAudioContext → WAV), `__render(t)`.
   - **timing helpers** (top of the script): `at(line, "word", nth=1)` returns when that word is
     spoken (case and punctuation ignored, misses logged as console errors), plus `lineStart(i)`,
     `lineEnd(i)`, `END` (the last word ends), `FIN` (the final chord, first bar line after `END`)
     and `DUR`. Key **every** scene boundary, wipe, shake and sound event to these. The reference
     still has literal seconds for its own scenes; don't copy that. Literals silently desync
     the moment the voice, `RATE`, `START` or `GAP` changes.
   - **per-project variation** (seeded by `SEED`): `MUS` generates the score (key, chord
     progression, voicing, melody, lead instrument, kick pattern, arpeggio shape) and fills
     `CHORDS`/`MEL`; `STYLE` picks the title paper (reused for the closing scene), a collage layout
     (`TITLE_LAYOUTS`), and the mascot's side and entrance. Never paste fixed chords or a melody
     back in, or every video will open with the same tune.
   - Placeholders filled by `build.mjs`: `{{F_<FontFile>}}`, `{{NARRATION}}`, `{{CUES}}`
     (with per-word timestamps), `{{DUR}}`, `{{SEED}}`. It warns about any placeholder left unfilled.
   - The first line must be `<meta charset="utf-8">`; without it every `€ × → ▲ … ’` turns to mojibake.
6. **Build + QA loop:** `SEED=<project-name> OUTDIR=<project>/demos/explainer node build.mjs`
   (always pass `SEED`; without it the first narration line is used, so editing that line changes the music), then
   `node shots.mjs <t1> <t2> …` (renders exact timeline times, prints console errors) and
   `./sheet.sh X.jpg t1 t2 t3 t4` (same times as passed to `shots.mjs`). Check every scene at
   least once, mid-animation and settled. Any `at(...)` miss shows up in the printed console errors.
   `node live.mjs` smoke-tests real playback, seek (to 66 % of `DUR`) and the scheduler in the browser.
7. **Mix:** `AUDIOONLY=1 node render.mjs` → `mix.wav`; `VG=0 WAV=music.wav AUDIOONLY=1 node render.mjs`
   gives a music+SFX stem, and `./stemcheck.sh music.wav` measures it. Then `./normalize.sh` → `mix_norm.wav`.
8. **Export:** `NOAUDIO=1 node render.mjs <name>.mp4` (in the background; it muxes the
   `mix_norm.wav` from step 7 and reads `DUR` from the page): 1920×1080, 30 fps,
   x264 CRF 20 capped at `-maxrate 7M -bufsize 14M`, `-tune animation`, AAC 192k, faststart.
   The cap keeps a 60 s video at ~50–55 MB so it can be **shared on WhatsApp (~64 MB limit)**; the
   film grain would otherwise push CRF alone to ~200 MB. `render.mjs` prints the size and warns above
   60 MB (`MAXMB`). Verify with ffprobe (duration, streams) and one contact sheet of frames
   pulled from the MP4 itself.
9. **Deliver** into the project dir: `index.html` (self-contained), the `.mp4`, a `README.md`
   (script table, beat-to-subsystem mapping, how it's made, how to rebuild) and `source/`
   (`src.html`, `lines.json`, `cues.json`, pipeline scripts).

## Craft rules (what makes it look and sound professional)

**Visual**
- Palette: warm vintage paper colours (kraft, cream, teal, mustard, tomato red, sky, pink,
  navy) with near-black ink `#1f1a17`. Give each scene its own backdrop paper (kraft, sky,
  graph paper, mint, legal pad, notebook, cream), and bookend with the same paper.
- **Make the opening this project's own.** The reference title card (logo + underline + subtitle,
  collage scraps, robot with a thought bubble) is one example, not a template. `STYLE` already
  varies the paper, layout and mascot entrance; on top of that, build the title card around an object
  or metaphor from *this* project (a registry box, a terminal, a device…), and change the subtitle
  device and the mascot's first action. If it could be mistaken for another explainer's opening, redo it.
- Everything is a cut-out: torn edges with a white paper rim, a soft offset shadow, and tape
  strips on important sheets. Mix fonts ransom-note style for the title only; it must still
  read correctly (watch for `l`→`1`, `n`→`N`, `e`→`E` in some display fonts).
- Motion: entrances use `outBack` pops (`pop(t,a)`), slides use `outCubic`/`inOut`, and a few
  elements get elastic or spring moves. Positions are smooth while ink and sprites boil at 10 fps.
  Add camera drift always, and small screen shakes on stamps and impacts.
- **Sync on the word:** every visual beat keys off `at(line, "word")` (in the reference build a
  check lands on "cash?", a stamp on "Only then", a freeze on "stops"). This does the most for
  perceived quality.
- One idea per beat, one focal point per moment. Keep a 60–80 px margin from the frame edges,
  and never let labels overlap other labels, headlines or the logo. The most common defects
  were bubbles over the title, chips over the wrong chart, captions colliding with arrows,
  text overflowing its sprite, and a scrolling strip that ran out (make loops seamless:
  3 repeats, scroll mod one repeat width).
- Use a torn-paper wipe (0.65 s) between scenes, plus a paper-rip sound. Fade in from black
  over 0.45 s and out over the last ~0.8 s.
- Use handwritten red annotations (the reference's "real prices ↖") to label concepts instead of subtitles.

**Audio**
- Voice sits on top. Measured targets: the music+SFX bed should run **9–15 dB under the voice**
  during speech (short-term), with ducking `1-0.6*k` around each cue and louder in gaps.
  Starting levels that worked were `musicLevel 0.3`, `sfx 0.5`, and master into a gentle
  compressor. The final mix is **−16 LUFS integrated, ≤ −1.5 dBTP**.
- The score is 100 BPM in a major key: pizzicato "oom-pah" + upright bass + a lead melody or arpeggios.
  Key, progression, melody, lead (glockenspiel, pluck or bell), kick pattern and arpeggio shape are
  seeded per project by `MUS`. The tempo stays fixed because `BAR` also drives `assemble.mjs`. Vary the texture per section (add shaker/snap/kick, a woodblock "clock" for
  tension). End with a final chord hit + sparkle + cymbal after the last word, preceded by a riser.
  The engine places these at `FIN` automatically.
- Use one dramatic audio gesture (e.g. a tape-stop to silence on "halt/stop") to punctuate
  the key safety or feature moment (the reference's `HALT_A`/`HALT_B`; derive yours from `at()`).
- Every visual event gets a sound: pops pitched and varied, scribbles for write-ons, thuds for
  stamps, whooshes for flights, and chimes on success checks. Keep SFX tasteful and never louder than the voice.
- You can't listen, so verify by measurement: `stemcheck.sh` for balance, `volumedetect` on
  windows for intended silences or peaks, `ebur128` for the final loudness.

## Gotchas

- Web Audio time shifting: **don't** proxy AudioContext/AudioParam objects (setting `.value`
  through a Proxy throws "Illegal invocation"). Use the engine's `SH` offset applied at the
  outermost `I`/`FX` call.
- `pkill -f` with a pattern that matches your own shell kills the tool call (exit 144).
  Kill by PID from `ps` instead.
- Headless Chrome needs `headless:"shell"` + `LD_LIBRARY_PATH` from setup.sh; `toDataURL`
  JPEG frames piped to ffmpeg `image2pipe` take ~110 ms/frame at 1080p.
- A mono narration file measures ~3 LU quieter than the same voice in the stereo mix, so
  compare like with like.
- Artifact hosting: offer to publish `index.html` as an Artifact only if the user wants a
  shareable link (it is fully self-contained, ~1.4 MB).

## Done when

- The MP4 and HTML both play start to finish with no console errors. Duration is 30–60 s, the
  audio is −16 LUFS, the MP4 is ≤ 60 MB, the voice is clearly on top, and every scene has passed a contact-sheet check.
- All speech and on-screen text is in the requested language (default English).
- The README documents the script, what each beat explains, how it was made and how to rebuild.
- Report to the user: the output paths, the length, the voice used, the known limitations, and
  that you could only verify audio by measurement.
