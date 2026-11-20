import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { Session, SelfSample, BleBin, StatusEvent } from "../packages/core/src/types";
const output = join(process.cwd(), "fixtures/synthetic");
mkdirSync(output, {recursive:true});
function rng(seed:number) {let x=seed>>>0||1;return()=>{x^=x<<13;x^=x>>>17;x^=x<<5;return(x>>>0)/4294967296};}
function self(t:number,x:number,z:number,quality:SelfSample["quality"]="usable"):SelfSample {
 return {tMs:t,segmentId:"synthetic-route",source:"synthetic",positionM:quality==="unavailable"?null:[x,0,z],
 horizontalAccuracyM:quality==="unavailable"?null:quality==="coarse"?35:5,ageMs:0,quality,headingDeg:90,
 headingAccuracyDeg:10,stepsDelta:1,stepsIntervalMs:1000,floor:null};
}
function session(id:string,durationMs:number,seed:number,ble:BleBin[],pos:SelfSample[],status?:StatusEvent[]):Session {
 return {schema:"signal-echoes.session",version:1,provenance:"synthetic",sessionId:id,durationMs,
 coordinateFrame:"local-east-up-south-m",seed,
 capture:{mode:"synthetic",serviceFilter:"none",binMs:1000,completion:"complete"},
 observations:{ble,self:pos,status:status??[
 {tMs:0,state:"recording",reason:"user_start",scanActive:true,droppedCount:0},
 {tMs:durationMs,state:"finished",reason:"user_stop",scanActive:false,droppedCount:0}]}}
}
const rise=session("demo-rise-001",10000,42,Array.from({length:10},(_,i)=>({
 tMs:(i+1)*1000,traceId:"demo-a",rssiMedianDbm:-80+i,sampleCount:3,lastSeenMs:(i+1)*1000-100
})),[self(1000,0,0),self(10000,9,0)]);
const quiet=session("demo-quiet-001",60000,11,[],Array.from({length:61},(_,i)=>self(i*1000,i*.15,0)),[
 {tMs:0,state:"recording",reason:"user_start",scanActive:true,droppedCount:0},
 ...Array.from({length:59},(_,i)=>({tMs:(i+1)*1000,state:"recording" as const,reason:"heartbeat",scanActive:true,droppedCount:0})),
 {tMs:60000,state:"finished",reason:"user_stop",scanActive:false,droppedCount:0}
]);
function flow():Session {
 const random=rng(2031),ble:BleBin[]=[],pos:SelfSample[]=[];
 const duration=180000;
 for(let t=0;t<=duration;t+=1000) pos.push(self(t,t/2000+Math.sin(t/21000)*5,Math.sin(t/13000)*12));
 for(let id=0;id<85;id++){
  const begin=Math.floor(id*1950/1000)*1000;
  const lifetime=18000+Math.floor(random()*95)*1000;
  const base=-90+random()*29,phase=random()*6.28,rate=(random()-.5)*.22;
  for(let t=begin+1000;t<=Math.min(duration,begin+lifetime);t+=1000){
   const elapsed=(t-begin)/1000;
   if((id%11===0 && elapsed%13<3)||(id%17===0&&elapsed%20<5))continue;
   const rssi=Math.max(-110,Math.min(-44,Math.round(base+Math.sin(elapsed*.23+phase)*7+rate*elapsed+(random()-.5)*6)));
   ble.push({tMs:t,traceId:"synthetic-trace-"+String(id).padStart(3,"0"),rssiMedianDbm:rssi,sampleCount:1+Math.floor(random()*5),lastSeenMs:t-100});
  }
 }
 ble.sort((a,b)=>a.tMs-b.tMs||a.traceId.localeCompare(b.traceId));
 return session("synthetic-city-flow",duration,2031,ble,pos);
}
const city=flow();
const gaps=session("demo-gaps-001",60000,71,Array.from({length:20},(_,i)=>{
 const t=(i<10?i+1:i+16)*1000;
 return {tMs:t,traceId:"synthetic-gap",rssiMedianDbm:-80+(i%5),sampleCount:2,lastSeenMs:t-100};
}),Array.from({length:61},(_,i)=>i>=14&&i<=22?self(i*1000,0,0,"unavailable"):self(i*1000,i*.4,2)),[
 {tMs:0,state:"recording",reason:"user_start",scanActive:true,droppedCount:0},
 {tMs:20000,state:"paused",reason:"app_inactive",scanActive:false,droppedCount:0},
 {tMs:24000,state:"recording",reason:"resumed",scanActive:true,droppedCount:0},
 {tMs:60000,state:"finished",reason:"user_stop",scanActive:false,droppedCount:0}]);
const noisy=session("demo-noisy-001",60000,37,Array.from({length:50},(_,i)=>({
 tMs:(i+1)*1000,traceId:i%13===0?"synthetic-spike":"synthetic-unstable",
 rssiMedianDbm:-74+(i%2?19:-20)+(i%7),sampleCount:2,lastSeenMs:(i+1)*1000-100
})),Array.from({length:61},(_,i)=>self(i*1000,i*.3,0)));
const indoor=session("demo-indoor-001",60000,8,city.observations.ble.filter(b=>b.tMs<=60000),
 Array.from({length:61},(_,i)=>self(i*1000,i*.3,Math.cos(i/6)*2,i>20&&i<35?"unavailable":i>35&&i<49?"coarse":"usable")));
const fixtures:{[key:string]:Session}={rise,quiet,flow:city,gaps,noisy,indoor};
const manifest:{name:string;sha256:string;durationMs:number;bleBins:number;seed:number}[]=[];
for(const [name,value] of Object.entries(fixtures)){
 const raw=JSON.stringify(value,null,2)+"\n";
 writeFileSync(join(output,name+".json"),raw);
 manifest.push({name,sha256:createHash("sha256").update(raw).digest("hex"),durationMs:value.durationMs,
 bleBins:value.observations.ble.length,seed:value.seed});
}
writeFileSync(join(output,"manifest.json"),JSON.stringify({generator:"synthetic-v1",fixtures:manifest},null,2)+"\n");
console.log("Synthetic fixtures:",manifest.map(v=>v.name+"("+v.bleBins+")").join(", "));
