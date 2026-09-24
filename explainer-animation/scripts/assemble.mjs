// Place trimmed lines (vo/t<i>.wav from cues.mjs) at their cue starts → narration.wav + narration.mp3
// Usage: node assemble.mjs   (DUR=<s> overrides the default: the first bar line after the last word + TAIL.
//        TAIL defaults to 3.3 s, BAR to 2.4 s = 4 beats at 100 BPM and must match BAR in src.html)
// Also writes timeline.json {dur}, the single source of the video length for build.mjs and render.mjs.
import fs from "fs"; import { execFileSync } from "child_process";
const F = "node_modules/ffmpeg-static/ffmpeg", cues = JSON.parse(fs.readFileSync("cues.json", "utf8"));
const TAIL = +(process.env.TAIL ?? 3.3);
const BAR = +(process.env.BAR ?? 2.4), END = cues.at(-1).start + cues.at(-1).dur;
const FIN = Math.ceil(END / BAR - 0.05) * BAR; // same formula as FIN in the engine
const DUR = +(process.env.DUR || (FIN + TAIL).toFixed(2));
const args = ["-y", "-loglevel", "error"]; let fl = "";
cues.forEach((c, k) => { args.push("-i", `vo/t${c.i}.wav`); const ms = Math.round(c.start * 1000); fl += `[${k}]adelay=${ms}|${ms}[a${k}];`; });
fl += cues.map((_, k) => `[a${k}]`).join("") + `amix=inputs=${cues.length}:normalize=0,apad=whole_dur=${DUR}[o]`;
execFileSync(F, [...args, "-filter_complex", fl, "-map", "[o]", "-ar", "44100", "-ac", "1", "narration.wav"]);
execFileSync(F, ["-y", "-loglevel", "error", "-i", "narration.wav", "-c:a", "libmp3lame", "-b:a", "112k", "narration.mp3"]);
fs.writeFileSync("timeline.json", JSON.stringify({ dur: DUR }));
console.log("narration.mp3 + timeline.json, DUR =", DUR);
