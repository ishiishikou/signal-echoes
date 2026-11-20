import type { Session, BleBin, RenderFrame, Particle, Trend } from "./types";
import { CONFIG } from "./config";
import { analyzeTrace, fnv1a32 } from "./signal";
import { selfAt } from "./self-path";
export type SessionIndex = {session:Session; traces:Map<string,BleBin[]>; keys:string[] };
export function createIndex(session:Session):SessionIndex {
  const traces = new Map<string,BleBin[]>();
  for (const b of session.observations.ble) {
    const a = traces.get(b.traceId) ?? [];
    a.push(b); traces.set(b.traceId,a);
  }
  for (const v of traces.values()) v.sort((a,b) => a.tMs-b.tMs);
  return {session,traces,keys:Array.from(traces.keys())};
}
function pastIndex(bins:BleBin[],atMs:number):number {
  let lo=0,hi=bins.length;
  while(lo<hi) {const m=(lo+hi)>>1; if(bins[m].tMs<=atMs)lo=m+1;else hi=m;}
  return lo;
}
export function getFrame(index:SessionIndex,rawMs:number):RenderFrame {
  const session=index.session, tMs=Math.max(0,Math.min(session.durationMs,rawMs));
  const p=selfAt(session.observations.self,tMs);
  const status = session.observations.status.filter(s=>s.tMs<=tMs).at(-1);
  const scanState = !status ? "unavailable" : (status.state==="recording" && status.scanActive ? "active" : "paused");
  const candidates:{id:string; bins:BleBin[];hash:number}[]=[];
  for(const id of index.keys) {
    const bins=index.traces.get(id)!;const n=pastIndex(bins,tMs);
    if(n===0)continue;
    const last=bins[n-1]; if(tMs-last.lastSeenMs>=CONFIG.VANISH_MS)continue;
    candidates.push({id,bins:bins.slice(Math.max(0,n-15),n),hash:fnv1a32(session.sessionId+"|"+id+"|"+session.seed)});
  }
  candidates.sort((a,b)=>a.hash-b.hash||a.id.localeCompare(b.id));
  const particles:Particle[]=[];
  const selectedTrend:Record<Trend,number> = {rising:0,falling:0,stable:0,variable:0,unknown:0};
  for(const c of candidates.slice(0,CONFIG.PARTICLE_LIMIT)) {
    const signal=analyzeTrace(c.bins,tMs);
    if(!signal)continue;
    const theta=2*Math.PI*(c.hash+0.5)/4294967296;
    const anchor = p.position ?? [0,0,0];
    const age = signal.ageMs;
    const opacity = age<=CONFIG.FRESH_MS ? 1 : Math.max(0,(CONFIG.VANISH_MS-age)/5000);
    const strength = signal.smoothRssiDbm ?? c.bins.at(-1)!.rssiMedianDbm;
    const intensity = Math.max(0.15,Math.min(1,(strength+95)/40));
    particles.push({id:c.id,virtualPosition:[anchor[0]+6*Math.cos(theta),anchor[1]+1.2,anchor[2]+6*Math.sin(theta)],
      intensity,opacity,stale:age>CONFIG.FRESH_MS,trend:signal.trend,quality:signal.quality,
      rssi:signal.smoothRssiDbm,anchorBasis:p.basis});
    selectedTrend[signal.trend]++;
  }
  return {atMs:tMs,self:p.position,anchorBasis:p.basis,headingDeg:p.headingDeg,
    particles,activeTraces:candidates.length,renderedTraces:particles.length,
    scanState,positionQuality:p.quality,statusReason:status?.reason ?? "unknown",selectedTrend};
}
