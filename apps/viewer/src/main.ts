import "./style.css";
import { createIndex, getFrame, parseSession, type Session, type SessionIndex, type ValidationResult, CONFIG } from "@signal-echoes/core";
import { createScene } from "./scene";
import flowData from "../../../fixtures/synthetic/flow.json";
import riseData from "../../../fixtures/synthetic/rise.json";
import quietData from "../../../fixtures/synthetic/quiet.json";
import gapsData from "../../../fixtures/synthetic/gaps.json";
import noisyData from "../../../fixtures/synthetic/noisy.json";
import indoorData from "../../../fixtures/synthetic/indoor.json";
type Mode = "overview"|"first"|"free";
const byId = <T extends HTMLElement>(id:string)=>document.getElementById(id) as T;
const sceneHost=byId<HTMLDivElement>("scene");
const timeline=byId<HTMLInputElement>("timeline"), clock=byId<HTMLSpanElement>("clock");
const play=byId<HTMLButtonElement>("play"),scenario=byId<HTMLSelectElement>("scenario");
const speed=byId<HTMLSelectElement>("speed"),heat=byId<HTMLDivElement>("timeline-heat");
const error=byId<HTMLDivElement>("error");
const scenarios:Record<string,unknown>={flow:flowData,rise:riseData,quiet:quietData,gaps:gapsData,noisy:noisyData,indoor:indoorData};
const labels:Record<string,string>={flow:"SYNTHETIC CITY FLOW",rise:"SIGNAL RISE",quiet:"QUIET PATH",gaps:"LOST MOMENTS",noisy:"STATIC / NOISY",indoor:"INDOOR CONDITIONS"};
let engine:ReturnType<typeof createScene>|null=null;
try{engine=createScene(sceneHost);}catch{byId<HTMLDivElement>("fallback").hidden=false;sceneHost.style.display="none";}
let index:SessionIndex|null=null,session:Session|null=null,current=0,playing=false,rate=1;
let lastFrameTime=0,lastUiTime=0,view:Mode="overview",reducedMotion=window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const format=(time:number)=>{const s=Math.floor(time/1000);return String(Math.floor(s/60)).padStart(2,"0")+":"+String(s%60).padStart(2,"0")};
function setError(message:string|null) {error.hidden=!message;if(message)error.textContent=message;}
function updateButtons(){play.textContent=playing?"Ⅱ":"▶";play.setAttribute("aria-label",playing?"一時停止":"再生");
  byId("playing-state").textContent=playing?"PLAYING":"PAUSED";}
function makeHeatmap(value:Session){
 const buckets=90,arr=Array.from({length:buckets},()=>0);
 for(const b of value.observations.ble){const at=Math.min(buckets-1,Math.floor(b.tMs/Math.max(1,value.durationMs)*buckets));arr[at]++;}
 const max=Math.max(1,...arr);
 heat.replaceChildren();
 for(let i=0;i<buckets;i++){const part=document.createElement("div");
  part.style.cssText="display:inline-block;vertical-align:bottom;width:"+100/buckets+"%;height:"+Math.max(2,Math.min(100,arr[i]/max*100))+"%;background:linear-gradient(0deg,rgba(49,139,155,.22),rgba(92,239,216,.76));";
  heat.appendChild(part);
 }
 heat.style.whiteSpace="nowrap";
}
function useValidatedSession(validated:ValidationResult,label:string){
 session=validated.session;index=createIndex(session);
 current=session.durationMs>25000?Math.min(session.durationMs-1000,Math.round(session.durationMs*.36/1000)*1000):session.durationMs;
 timeline.max=String(session.durationMs);timeline.value=String(current);
 byId("session-label").textContent=label;
 byId("provenance").textContent=session.provenance==="synthetic"?"SYNTHETIC DATA":"LOCAL MEASUREMENT";
 byId("source-kind").textContent=session.provenance==="synthetic"?"合成データ":"ローカル実測";
 engine?.setSession(session);makeHeatmap(session);
 playing=false;updateButtons();setError(validated.reorderedRecords?"入力時系列を並べ直しました（"+validated.reorderedRecords+"件）":null);
 update(true);
}
function useSession(raw:unknown,label:string){
 useValidatedSession(parseSession(JSON.stringify(raw)),label);
}
async function importLocalFile(file:File):Promise<ValidationResult>{
 const worker=new Worker(new URL("./import-worker.ts",import.meta.url),{type:"module"});
 try{
   const bytes=await file.arrayBuffer();
   return await new Promise<ValidationResult>((resolve,reject)=>{
     worker.onmessage=(event:MessageEvent<{ok:boolean;result?:ValidationResult}>)=>{
       if(event.data.ok&&event.data.result)resolve(event.data.result);
       else reject(new Error("INVALID_SESSION"));
     };
     worker.onerror=()=>reject(new Error("WORKER_FAILED"));
     worker.postMessage(bytes,[bytes]);
   });
 }finally{worker.terminate();}
}
function selectView(v:Mode){
 view=v;engine?.setView(v);
 for(const b of document.querySelectorAll<HTMLButtonElement>("[data-view]")){
  const active=b.dataset.view===v;b.classList.toggle("active",active);b.setAttribute("aria-pressed",String(active));
 }
}
function update(force=false){
 if(!session||!index)return;
 const frame=getFrame(index,current);
 engine?.draw(frame,reducedMotion);
 if(force||performance.now()-lastUiTime>110){
  lastUiTime=performance.now();
  timeline.value=String(Math.min(current,session.durationMs));
  timeline.style.background="linear-gradient(to right,#68e5d8 "+current/Math.max(1,session.durationMs)*100+"%,rgba(92,143,161,.24) 0%)";
  clock.textContent=format(current)+" / "+format(session.durationMs);
  byId("active-count").textContent=String(frame.renderedTraces).padStart(2,"0");
  byId("rising-count").textContent=String(frame.selectedTrend.rising);
  byId("falling-count").textContent=String(frame.selectedTrend.falling);
  byId("other-count").textContent=String(frame.renderedTraces-frame.selectedTrend.rising-frame.selectedTrend.falling);
  byId("meter-fill").style.width=Math.min(100,frame.renderedTraces/Math.max(1,CONFIG.PARTICLE_LIMIT)*100)+"%";
  byId("position-quality").textContent=frame.anchorBasis==="fixed_stage"?"位置不明 / 演出":frame.anchorBasis==="interpolated_self"?"区間補間":"自己位置記録";
  byId("scan-state").textContent=frame.scanState==="active"?"記録区間":frame.scanState==="paused"?"記録停止・終了":"不明";
 }
}
function loop(now:number){
 if(playing && session) {
  if(lastFrameTime)current=Math.min(session.durationMs,current+Math.min(now-lastFrameTime,80)*rate);
  if(current>=session.durationMs){playing=false;updateButtons();}
 }
 lastFrameTime=now;update();requestAnimationFrame(loop);
}
play.addEventListener("click",()=>{if(!session)return;if(current>=session.durationMs)current=0;playing=!playing;updateButtons();update(true);});
byId<HTMLButtonElement>("restart").addEventListener("click",()=>{current=0;update(true);});
byId<HTMLButtonElement>("step").addEventListener("click",()=>{if(!session)return;current=Math.min(session.durationMs,current+10000);update(true);});
timeline.addEventListener("input",()=>{playing=false;updateButtons();current=Number(timeline.value);update(true);});
speed.addEventListener("change",()=>{rate=Number(speed.value);});
scenario.addEventListener("change",()=>{const key=scenario.value;try{useSession(scenarios[key],labels[key]);}catch{setError("合成データの読み込みに失敗しました。");}});
for(const b of document.querySelectorAll<HTMLButtonElement>("[data-view]")){
 b.addEventListener("click",()=>selectView(b.dataset.view as Mode));
}
byId<HTMLButtonElement>("reset-camera").addEventListener("click",()=>engine?.reset());
byId<HTMLInputElement>("file-input").addEventListener("change",async e=>{
 const input=e.currentTarget as HTMLInputElement,file=input.files?.[0];if(!file)return;
 input.value="";
 if(file.size>CONFIG.MAX_BYTES){setError("ファイルの上限は50MiBです。");return;}
 try{
   const validated=await importLocalFile(file);
   useValidatedSession(validated,"LOCAL FILE / "+(validated.session.provenance==="synthetic"?"SYNTHETIC":"MEASURED"));
   scenario.value=""; // A separate, local-only session
 }catch{setError("読み込めないデータです。JSON形式とスキーマを確認してください。元のデータは保持します。");}
});
document.addEventListener("keydown",e=>{
 const target=e.target as HTMLElement;if(["INPUT","SELECT","BUTTON","TEXTAREA"].includes(target.tagName))return;
 if(e.code==="Space"){e.preventDefault();play.click();}
 if(e.code==="ArrowLeft"&&session){current=Math.max(0,current-5000);update(true);}
 if(e.code==="ArrowRight"&&session){current=Math.min(session.durationMs,current+5000);update(true);}
});
document.addEventListener("visibilitychange",()=>{if(document.hidden){playing=false;updateButtons();lastFrameTime=0;}});
try{useSession(scenarios.flow,labels.flow);}catch{setError("初期の合成シーンを読み込めませんでした。");}
selectView("overview");requestAnimationFrame(loop);
