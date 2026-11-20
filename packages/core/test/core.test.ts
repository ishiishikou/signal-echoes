import { describe,it,expect } from "vitest";
import { readFileSync } from "node:fs";
import { CONFIG, parseSession, SessionError, bleBinEnd, acceptableRSSI, positionQuality,
  expires, createIndex, getFrame, analyzeTrace, selfAt, fnv1a32, makePathSegments,
  type Session } from "../src/index";
function fixture(name:string):Session{return parseSession(readFileSync("fixtures/synthetic/"+name+".json","utf-8")).session;}
const clone=<T>(value:T):T=>JSON.parse(JSON.stringify(value));
describe("Session v1 data contract",()=>{
 it("accepts all generated synthetic scenarios",()=>{
  for(const name of ["flow","rise","quiet","gaps","noisy","indoor"]) expect(fixture(name).provenance).toBe("synthetic");
 });
 it("validates finite values, unknown keys, version, duplicate bins and wrong provenance",()=>{
  const orig=fixture("rise");
  const cases=[
   {...orig,version:2},
   {...orig,unwanted:"bad"},
   {...orig,capture:{...orig.capture,mode:"foreground"}},
   {...orig,observations:{...orig.observations,ble:[...orig.observations.ble,orig.observations.ble[0]]}},
   {...orig,observations:{...orig.observations,self:[{...orig.observations.self[0],positionM:null}]}},
   {...orig,observations:{...orig.observations,ble:[{...orig.observations.ble[0],rssiMedianDbm:127}]}},
  ];
  for(const c of cases) expect(()=>parseSession(JSON.stringify(c))).toThrow(SessionError);
 });
 it("sorts unsorted bins without accepting duplicates",()=>{
  const v=fixture("rise"),c=clone(v);c.observations.ble.reverse();
  const out=parseSession(JSON.stringify(c));
  expect(out.reorderedRecords).toBeGreaterThan(0);expect(out.session.observations.ble[0].tMs).toBe(1000);
 });
 it("rejects files over 50MiB and malformed JSON",()=>{
  expect(()=>parseSession("")).toThrow("INVALID_JSON");
  expect(()=>parseSession(" ".repeat(CONFIG.MAX_BYTES+1))).toThrow("FILE_TOO_LARGE");
 });
 it("maps callback timestamps at bin edges and rejects invalid RSSI",()=>{
  expect(bleBinEnd(999)).toBe(1000);expect(bleBinEnd(1000)).toBe(2000);
  expect(acceptableRSSI(127)).toBe(false);expect(acceptableRSSI(-128)).toBe(false);
  expect(acceptableRSSI(20)).toBe(true);expect(acceptableRSSI(0)).toBe(true);
 });
});
describe("No tracking and source-position claims",()=>{
 it("expires short tokens at exact 120s/30s boundaries and clears on pause",()=>{
   expect(expires({token:"x",bornMs:0,lastSeenMs:119999},119999)).toBe(false);
   expect(expires({token:"x",bornMs:0,lastSeenMs:119999},120000)).toBe(true);
   expect(expires({token:"x",bornMs:0,lastSeenMs:0},29999)).toBe(false);
   expect(expires({token:"x",bornMs:0,lastSeenMs:0},30000)).toBe(true);
 });
 it("does not infer a person, distance or direction from signal changes",()=>{
   const bins=fixture("rise").observations.ble;
   const a=analyzeTrace(bins,10000);
   expect(a?.physicalMotion).toBe("unknown");
   expect(a?.sourceDirection).toBe(null);expect(a?.sourceDistanceM).toBe(null);
   expect(a?.trend).toBe("rising");
   expect(a?.quality).toBe("sufficient");
   expect(a?.smoothRssiDbm).toBe(-73);
   expect(a?.slopeDbPerSec).toBeCloseTo(1,8);
   expect(a?.residualMADDb).toBe(0);
 });
 it("uses deterministic virtual coordinates but never claims physical positions",()=>{
   const session=fixture("rise"),i=createIndex(session);
   const f=getFrame(i,10000),p=f.particles[0];
   expect(f.anchorBasis).toBe("observed_self");
   expect(p.virtualPosition[0]).toBeCloseTo(14.5956,4);
   expect(p.virtualPosition[1]).toBe(1.2);
   expect(p.virtualPosition[2]).toBeCloseTo(-2.1654,4);
   expect(p.intensity).toBeCloseTo(.55,8);
   expect(p.opacity).toBe(1);
   expect(getFrame(i,10000)).toEqual(f);
   const other=clone(session);other.seed++;
   expect(getFrame(createIndex(other),10000).particles[0].virtualPosition).not.toEqual(p.virtualPosition);
   expect(analyzeTrace(other.observations.ble,10000)).toEqual(analyzeTrace(session.observations.ble,10000));
 });
 it("makes no plausible path from a 9-second measurement gap",()=>{
   const session=fixture("rise");
   expect(selfAt(session.observations.self,5500).basis).toBe("fixed_stage");
   expect(makePathSegments(session.observations.self).every(v=>v.length<2)).toBe(true);
 });
 it("displays no detections as an absence of received records only",()=>{
   const f=getFrame(createIndex(fixture("quiet")),35000);
   expect(f.particles).toHaveLength(0);expect(f.scanState).toBe("active");
 });
 it("distinguishes a pause from an empty scan",()=>{
   const f=getFrame(createIndex(fixture("gaps")),22000);
   expect(f.scanState).toBe("paused");
 });
 it("bounds time and is independent of future observations",()=>{
   const session=fixture("flow"),index=createIndex(session);
   expect(getFrame(index,-2000).atMs).toBe(0);
   expect(getFrame(index,1e10).atMs).toBe(session.durationMs);
   const earlier=getFrame(index,30000);
   const modified=clone(session);
   modified.observations.ble=modified.observations.ble.filter(x=>x.tMs<=30000);
   expect(getFrame(createIndex(modified),30000).particles).toEqual(earlier.particles);
 });
 it("uses bounded self position quality",()=>{
   expect(positionQuality(-1,0)).toBe("unavailable");
   expect(positionQuality(20,0)).toBe("usable");
   expect(positionQuality(20.1,0)).toBe("coarse");
   expect(positionQuality(50,0)).toBe("coarse");
   expect(positionQuality(50.1,0)).toBe("unavailable");
   expect(positionQuality(20,5000)).toBe("usable");
   expect(positionQuality(20,5001)).toBe("unavailable");
 });
});
