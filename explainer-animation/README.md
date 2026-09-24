# explainer-animation

An agent skill that produces a 30–60 second explainer video about the project it runs in.
The video is a hand-drawn, paper-collage animation with narration, a synthesised score and
sound effects. Everything is generated in code: the visuals are canvas and the audio is Web
Audio. There are no stock assets, video editors or paid services.

The skill is written for the agent (`SKILL.md`). This file is for the humans installing and
maintaining it.

## What you get

In a directory inside the project (e.g. `demos/explainer/`):

| File | What it is |
|---|---|
| `index.html` | Self-contained player (~1.4 MB) with fonts, narration and score embedded. Play/pause, seek, fullscreen. Works offline. |
| `<name>.mp4` | 1920×1080, 30 fps, H.264 + AAC, loudness-normalised to −16 LUFS. Bitrate-capped to ~50–55 MB per minute, so it fits WhatsApp's ~64 MB video limit. |
| `README.md` | The script, what each beat explains, how it was made and how to rebuild it. |
| `source/` | `src.html`, `lines.json`, `cues.json` and the pipeline scripts, to rebuild or tweak. |

Nothing is committed unless you ask.

## Install and use

```bash
skill-add explainer-animation        # in the project root
```

Then ask the agent for "an explainer video for this project", or run `/explainer-animation`.
You can add a narration language ("in Dutch") and a budget ("keep it under $5"). The defaults
are English and about $10 of tokens.

The skill is designed to run unattended. Expect roughly 30–60 minutes of wall-clock time; the
MP4 render alone takes ~7 minutes on a small VM.

## Requirements

- Linux x86_64, Node.js 18+ and npm. No sudo needed.
- Debian/Ubuntu if headless Chrome is missing shared libraries: `setup.sh` fetches them with
  `apt-get download` into the scratch directory. On other distros, install the libraries it lists.
- About 400 MB of scratch disk space.
- Outbound network access to npm, Google Fonts and Microsoft's Edge read-aloud TTS service.

**About the TTS:** narration uses [`msedge-tts`](https://www.npmjs.com/package/msedge-tts), which
talks to the unofficial, keyless endpoint behind Edge's read-aloud feature. It's free and sounds
good, but it can rate-limit or break without warning. The skill only uses a paid TTS service
(ElevenLabs, OpenAI…) when you explicitly ask for one.

## How it works

```
lines.json ──tts.mjs──▶ per-line mp3 + word boundaries
            ──cues.mjs──▶ trimmed, normalised lines + cues.json (per-word timestamps)
            ──assemble.mjs──▶ narration.mp3 + timeline.json (total duration)
src.html + fonts + narration + cues ──build.mjs──▶ out.html / index.html
out.html ──shots.mjs / sheet.sh──▶ contact sheets for visual QA
         ──render.mjs AUDIOONLY──▶ mix.wav ──normalize.sh──▶ mix_norm.wav
         ──render.mjs NOAUDIO──▶ frames piped to ffmpeg ──▶ .mp4
```

Every visual beat and sound effect is timed from the narration's word timestamps, using
`at(line, "word")` in the engine. That keeps the picture in sync when the voice or pacing changes.
The video length is computed once, in `assemble.mjs`, and everything else reads it from there.

Each project also gets its own music and opening. `build.mjs` passes a seed (`SEED=<project name>`)
into the engine, which uses it to pick the key, chord progression, melody, lead instrument and groove,
plus the title card's paper, collage layout and mascot entrance. Rebuilding the same project gives the
same result.

## Layout

| Path | Purpose |
|---|---|
| `SKILL.md` | Agent instructions: pipeline, craft rules, gotchas, definition of done. |
| `scripts/setup.sh` | Sudo-free toolchain: ffmpeg-static, msedge-tts, puppeteer + headless shell, missing Chrome libs. |
| `scripts/tts.mjs` | Neural TTS per line with word-boundary metadata; `--voices <locale>` lists voices. |
| `scripts/cues.mjs` | Silence trim, two-pass loudness normalisation, absolute word timestamps. |
| `scripts/assemble.mjs` | Places the lines on the timeline and writes the duration. |
| `scripts/fonts.sh` | Downloads Google Fonts as woff2 (`SUBSET=` for non-Latin scripts). |
| `scripts/build.mjs` | Fills the placeholders in `src.html` and writes the self-contained page. |
| `scripts/shots.mjs`, `sheet.sh` | Renders exact timeline frames and makes 2×2 contact sheets. |
| `scripts/live.mjs` | Browser smoke test for real-time playback, seek and the audio scheduler. |
| `scripts/render.mjs` | Offline audio render and frame-accurate MP4 export. |
| `scripts/normalize.sh`, `stemcheck.sh` | Final loudness normalisation and music/voice balance check. |
| `reference/engine-example.html` | Full working example (the hnl-trader explainer). The engine is reused; the scenes are not. |

## Maintaining

- Keep `SKILL.md` under 500 lines; put overflow in `reference/`.
- `BAR` (2.4 s at 100 BPM) appears in both `assemble.mjs` and the engine. Change them together.
  This is also why the seeded score varies key and style but not tempo.
- To add variety, extend the pools in `MUS` (progressions, rhythms, leads) and `TITLE_LAYOUTS` in
  `reference/engine-example.html`. Keep the logo band (roughly y 220–380) clear in every layout: a long name spans the full width.
- To check a change end to end without a new project, copy `scripts/*` to a scratch dir, provide
  a `lines.json` (an array of strings) and run steps 1–7 from `SKILL.md` with
  `reference/engine-example.html` as `src.html`. `shots.mjs` and `live.mjs` should print no errors.
