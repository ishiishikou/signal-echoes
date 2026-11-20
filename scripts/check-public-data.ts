import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
const base="fixtures/synthetic";
const manifest=JSON.parse(readFileSync(join(base,"manifest.json"),"utf8")) as
 {generator:string;fixtures:{name:string;sha256:string;durationMs:number;bleBins:number;seed:number}[]};
const failures:string[]=[];
if(manifest.generator!=="synthetic-v1")failures.push("generator version");
const expected=new Set(manifest.fixtures.map(v=>v.name+".json").concat("manifest.json"));
for(const f of readdirSync(base))if(!expected.has(f))failures.push("unexpected fixture: "+f);
for(const v of manifest.fixtures){
 const p=join(base,v.name+".json"),raw=readFileSync(p,"utf8"),obj=JSON.parse(raw);
 if(createHash("sha256").update(raw).digest("hex")!==v.sha256)failures.push("digest: "+v.name);
 if(obj.provenance!=="synthetic"||obj.capture?.mode!=="synthetic")failures.push("provenance: "+v.name);
 if(!obj.sessionId.startsWith("demo-")&&!obj.sessionId.startsWith("synthetic-"))failures.push("sessionId: "+v.name);
 if(obj.observations?.ble?.length!==v.bleBins)failures.push("ble count: "+v.name);
 if(/latitude|longitude|CBPeer|manufacturerData|advertisementData|deviceName|macAddress|appleId/i.test(raw))failures.push("raw identifiers: "+v.name);
}
const candidates=execFileSync("git",["ls-files","--cached","--others","--exclude-standard"],{encoding:"utf8"}).trim().split("\n").filter(Boolean);
for(const path of candidates){
 if(/(^|\/)\.env|\.p12$|\.ipa$|\.mobileprovision$|\.ndjson$|\.csv$|\.pem$|\.key$/i.test(path))failures.push("forbidden file: "+path);
 if(/\.json$/i.test(path)&&!path.startsWith("fixtures/synthetic/")&&!/(^|\/)(package(-lock)?|tsconfig)\.json$/.test(path))failures.push("unreviewed JSON: "+path);
 if(path.startsWith("apps/viewer/public/")&&path.toLowerCase().endsWith(".json"))failures.push("published JSON: "+path);
 if(/raw|measured|private|captures|exports/i.test(path)&&!path.endsWith(".md"))failures.push("suspicious filename: "+path);
}
if(failures.length){console.error("PUBLIC DATA REVIEW FAILED:",failures.join("; "));process.exitCode=1;}
else console.log("PUBLIC DATA REVIEW PASSED:",manifest.fixtures.length,"deterministic synthetic fixtures,",candidates.length,"candidate files");
