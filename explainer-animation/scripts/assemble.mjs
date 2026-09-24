// Place trimmed lines (vo/t<i>.wav from cues.mjs) at their cue starts → narration.wav + narration.mp3
// Usage: DUR=58.5 node assemble.mjs
import fs from "fs"; import { execFileSync } from "child_process";
const F = "node_modules/ffmpeg-static/ffmpeg", cues = JSON.parse(fs.readFileSync("cues.json", "utf8"));
const DUR = +(process.env.DUR || (cues.at(-1).start + cues.at(-1).dur + 3.3).toFixed(2));
const args = ["-y", "-loglevel", "error"]; let fl = "";
cues.forEach((c, k) => { args.push("-i", `vo/t${c.i}.wav`); const ms = Math.round(c.start * 1000); fl += `[${k}]adelay=${ms}|${ms}[a${k}];`; });
fl += cues.map((_, k) => `[a${k}]`).join("") + `amix=inputs=${cues.length}:normalize=0,apad=whole_dur=${DUR}[o]`;
execFileSync(F, [...args, "-filter_complex", fl, "-map", "[o]", "-ar", "44100", "-ac", "1", "narration.wav"]);
execFileSync(F, ["-y", "-loglevel", "error", "-i", "narration.wav", "-c:a", "libmp3lame", "-b:a", "112k", "narration.mp3"]);
console.log("narration.mp3, DUR =", DUR);
