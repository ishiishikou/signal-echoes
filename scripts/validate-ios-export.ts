import {readFileSync} from "node:fs";
import {strict as assert} from "node:assert";
import {parseSession} from "../packages/core/src/index";

const path = process.argv[2];
if (!path) throw Error("Usage: tsx scripts/validate-ios-export.ts <synthetic-swift-json>");
const raw = readFileSync(path,"utf8");
const {session} = parseSession(raw);
assert.equal(session.provenance,"measured");
assert.equal(session.capture.mode,"foreground");
assert.equal(session.capture.serviceFilter,"none");
assert.equal(session.capture.binMs,1000);
assert.equal(session.capture.completion,"complete");
assert.equal(session.observations.ble.length,1);
assert.equal(session.observations.self.length,1);
assert.equal(session.observations.self[0].positionM,null);
assert.equal(session.observations.self[0].floor,null);
assert.equal(session.observations.status.filter(x=>x.state==="finished").length,1);
for(const forbidden of ["manufacturerData","advertisementData","deviceName","latitude","longitude","macAddress"]){
 assert.equal(raw.includes(forbidden),false,`Raw field must not be exported: ${forbidden}`);
}
console.log("Swift Session V1 -> TypeScript Zod strict parse OK");