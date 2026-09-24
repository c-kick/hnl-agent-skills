import fs from "fs"; import {execSync} from "child_process";
const F="node_modules/ffmpeg-static/ffmpeg";
fs.mkdirSync("vo",{recursive:true});
const wb=JSON.parse(fs.readFileSync("wb.json","utf8"));
const GAP=+(process.env.GAP??0.75), START=+(process.env.START??1.6);
let t=START; const cues=[];
for (const {i,meta} of wb){
  const src=`wb/${i}/audio.mp3`;
  const sd=execSync(`${F} -i ${src} -af silencedetect=n=-50dB:d=0.05 -f null - 2>&1`).toString();
  const m=sd.match(/silence_start: (-?[\d.]+)[\s\S]*?silence_end: ([\d.]+)/);
  const lead = (m && parseFloat(m[1])<=0.01) ? parseFloat(m[2]) : 0;
  execSync(`${F} -y -loglevel error -i ${src} -af "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-16:TP=-1.5:LRA=7" -ar 44100 -ac 1 vo/t${i}.wav`);
  const dur=parseFloat(execSync(`${F} -i vo/t${i}.wav 2>&1 || true`).toString().match(/Duration: (\d+):(\d+):([\d.]+)/).slice(3)[0]);
  const words=JSON.parse(meta).Metadata.filter(x=>x.Type==="WordBoundary").map(x=>({w:x.Data.text.Text,t:+(t+x.Data.Offset/1e7-lead).toFixed(3)}));
  cues.push({i,start:+t.toFixed(3),dur:+dur.toFixed(3),words});
  t+=dur+GAP;
}
fs.writeFileSync("cues.json",JSON.stringify(cues,null,0));
for(const c of cues) console.log(c.i,c.start,c.dur,c.words.map(w=>w.w+"@"+w.t).join(" "));
console.log("end speech",t-GAP);
