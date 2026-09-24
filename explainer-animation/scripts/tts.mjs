// Neural TTS (Microsoft Edge voices, free, no key) with word-boundary metadata, one call per line.
// Usage: VOICE=en-US-AndrewMultilingualNeural RATE=-4% node tts.mjs lines.json
// Writes wb/<i>/audio.mp3 + metadata, and wb.json (consumed by cues.mjs).
// List voices: node tts.mjs --voices [locale-prefix]
import { MsEdgeTTS, OUTPUT_FORMAT } from "msedge-tts";
import fs from "fs";
if (process.argv[2] === "--voices") {
  const v = await new MsEdgeTTS().getVoices(); const pre = process.argv[3] || "";
  for (const x of v.filter(x => x.Locale.startsWith(pre))) console.log(x.ShortName, x.Gender, (x.VoiceTag?.VoicePersonalities || []).join(","));
  process.exit(0);
}
const VOICE = process.env.VOICE || "en-US-AndrewMultilingualNeural", RATE = process.env.RATE || "-4%";
const lines = JSON.parse(fs.readFileSync(process.argv[2] || "lines.json", "utf8"));
const out = [];
for (const [i, text] of lines.entries()) {
  for (let attempt = 1; ; attempt++) {
    const tts = new MsEdgeTTS();
    try {
      await tts.setMetadata(VOICE, OUTPUT_FORMAT.AUDIO_24KHZ_96KBITRATE_MONO_MP3, { wordBoundaryEnabled: true });
      const dir = `wb/${i}`; fs.mkdirSync(dir, { recursive: true });
      const r = await tts.toFile(dir, text, { rate: RATE });
      out.push({ i, meta: fs.readFileSync(r.metadataFilePath, "utf8") });
      console.log(i, "ok"); break;
    } catch (e) { if (attempt >= 3) throw e; console.log(i, "retry", e.message); }
    finally { try { tts.close(); } catch {} }
  }
}
fs.writeFileSync("wb.json", JSON.stringify(out));
