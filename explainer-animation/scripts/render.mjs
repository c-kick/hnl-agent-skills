import puppeteer from "puppeteer";import fs from "fs";import {spawn} from "child_process";
const FPS=30,DUR=58.5,F="node_modules/ffmpeg-static/ffmpeg",OUT=process.argv[2]||"video.mp4";
const b=await puppeteer.launch({headless:"shell",args:["--no-sandbox"],protocolTimeout:600000});
const p=await b.newPage();await p.setViewport({width:1920,height:1080});
p.on("pageerror",e=>console.log("PAGEERR",e.message));
await p.goto("file://"+process.cwd()+"/out.html?render",{waitUntil:"load"});await p.waitForFunction("window.__ready===true",{timeout:60000});
if(!process.env.NOAUDIO){const wav=await p.evaluate((vg)=>{if(vg!==undefined)window.__voiceGain=vg;return window.__renderAudio()},process.env.VG===undefined?undefined:+process.env.VG);fs.writeFileSync(process.env.WAV||"mix.wav",Buffer.from(wav,"base64"));console.log("audio ok")}
if(process.env.AUDIOONLY){await b.close();process.exit(0)}
const ff=spawn(F,["-y","-loglevel","error","-f","image2pipe","-framerate",String(FPS),"-c:v","mjpeg","-i","-","-i","mix_norm.wav","-c:v","libx264","-preset","slow","-crf","17","-pix_fmt","yuv420p","-tune","animation","-c:a","aac","-b:a","192k","-shortest","-movflags","+faststart",OUT],{stdio:["pipe","inherit","inherit"]});
const N=Math.round(DUR*FPS);const t0=Date.now();
for(let i=0;i<N;i++){const d=await p.evaluate(t=>{window.__render(t);return document.getElementById("c").toDataURL("image/jpeg",0.95)},i/FPS);
  const buf=Buffer.from(d.split(",")[1],"base64");if(!ff.stdin.write(buf))await new Promise(r=>ff.stdin.once("drain",r));
  if(i%150===0)console.log("frame",i,"/",N,((Date.now()-t0)/1000).toFixed(0)+"s")}
ff.stdin.end();await new Promise(r=>ff.on("close",r));await b.close();console.log("done",OUT);
