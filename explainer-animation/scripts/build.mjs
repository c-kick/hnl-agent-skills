import fs from "fs";
let s=fs.readFileSync("src.html","utf8");
// every {{F_Name}} placeholder is filled from fonts/Name.woff2
s=s.replace(/\{\{F_(\w+)\}\}/g,(_,f)=>fs.readFileSync(`fonts/${f}.woff2`).toString("base64"));
s=s.replace("{{NARRATION}}",fs.readFileSync("narration.mp3").toString("base64"));
const cues=JSON.parse(fs.readFileSync("cues.json","utf8")).map(c=>({start:c.start,dur:c.dur}));
s=s.replace("{{CUES}}",JSON.stringify(cues));
const OUTDIR=process.env.OUTDIR;if(OUTDIR){fs.mkdirSync(OUTDIR,{recursive:true});fs.writeFileSync(OUTDIR+"/index.html",s)}
fs.writeFileSync("out.html",s);
console.log("built",(s.length/1024).toFixed(0)+"KB");
