import puppeteer from "puppeteer";
const b=await puppeteer.launch({headless:"shell",args:["--no-sandbox","--autoplay-policy=no-user-gesture-required"]});
const p=await b.newPage();await p.setViewport({width:1280,height:800});
const errs=[];p.on("console",m=>{if(["error","warning"].includes(m.type()))errs.push(m.text())});p.on("pageerror",e=>errs.push("PAGEERR "+e.message));
await p.goto("file://"+process.cwd()+"/out.html",{waitUntil:"load"});await p.waitForFunction("window.__ready===true");
await p.click("#play");await new Promise(r=>setTimeout(r,2500));
const a=await p.evaluate(()=>[document.getElementById("time").textContent,document.getElementById("seek").value,AC&&AC.state]);
await p.evaluate(()=>{const s=document.getElementById("seek");s.value=(DUR*0.66).toFixed(2);s.dispatchEvent(new Event("input"));s.dispatchEvent(new Event("change"))});
await new Promise(r=>setTimeout(r,1500));
const c=await p.evaluate(()=>[document.getElementById("time").textContent,EVENTS.length,evIdx]);
// expect: a = [~0:02 / total, >0, "running"], c = [time near 66% of DUR, events, evIdx > 0], errs = []
await p.screenshot({path:"live.jpg",type:"jpeg",quality:70});
console.log(a,c,errs);await b.close();
