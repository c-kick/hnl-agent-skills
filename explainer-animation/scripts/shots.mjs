import puppeteer from "puppeteer";
const times=process.argv.slice(2).map(Number);
const b=await puppeteer.launch({headless:"shell",args:["--no-sandbox","--autoplay-policy=no-user-gesture-required"]});
const p=await b.newPage();await p.setViewport({width:1920,height:1080});
const errs=[];p.on("console",m=>{if(m.type()==="error"||m.type()==="warning")errs.push(m.text())});p.on("pageerror",e=>errs.push("PAGEERR "+e.message));
await p.goto("file://"+process.cwd()+"/out.html?render",{waitUntil:"load"});
await p.waitForFunction("window.__ready===true",{timeout:60000});
for(const t of times){const t0=Date.now();const d=await p.evaluate(t=>{window.__render(t);return document.getElementById("c").toDataURL("image/jpeg",0.85)},t);
  (await import("fs")).writeFileSync(`shot_${t}.jpg`,Buffer.from(d.split(",")[1],"base64"));console.log(t,Date.now()-t0,"ms")}
console.log(errs.join("\n"));await b.close();
