import { sessionSchema } from "./schema";
import type { Session } from "./types";
import { CONFIG } from "./config";
export class SessionError extends Error { constructor(public readonly code: string) { super(code); this.name = "SessionError"; } }
export type ValidationResult = { session: Session; reorderedRecords: number };
function depth(value: unknown): number {
  let high = 0;
  const stack: Array<{value: unknown; level: number}> = [{value, level: 0}];
  while (stack.length) {
    const current = stack.pop()!;
    high = Math.max(high, current.level);
    if (high > 10) return high;
    if (Array.isArray(current.value)) {
      for (const child of current.value) if (child && typeof child === "object") stack.push({value:child,level:current.level+1});
    } else if (current.value && typeof current.value === "object") {
      for (const child of Object.values(current.value)) if (child && typeof child === "object") stack.push({value:child,level:current.level+1});
    }
  }
  return high;
}
export function parseSession(json: string): ValidationResult {
  if (new TextEncoder().encode(json).byteLength > CONFIG.MAX_BYTES) throw new SessionError("FILE_TOO_LARGE");
  let raw: unknown;
  try { raw = JSON.parse(json); } catch { throw new SessionError("INVALID_JSON"); }
  if (depth(raw) > 10) throw new SessionError("TOO_DEEP");
  const result = sessionSchema.safeParse(raw);
  if (!result.success) throw new SessionError("INVALID_SCHEMA");
  const session = result.data as Session;
  if (session.provenance === "synthetic" && session.capture.mode !== "synthetic" ||
      session.provenance === "measured" && session.capture.mode !== "foreground") throw new SessionError("INVALID_PROVENANCE");
  const {ble, self, status} = session.observations;
  if (ble.length + self.length + status.length > CONFIG.MAX_EVENTS) throw new SessionError("TOO_MANY_EVENTS");
  let reordered = 0;
  for (const events of [ble, self, status]) {
    events.forEach((v, i) => { if (v.tMs > session.durationMs) throw new SessionError("OUT_OF_DURATION");
      if (i && events[i - 1].tMs > v.tMs) reordered++; });
    events.sort((a,b) => a.tMs - b.tMs);
  }
  const keys = new Set<string>();
  for (const v of ble) {
    if (v.tMs % CONFIG.BIN_MS !== 0 || v.tMs === 0 || v.tMs - CONFIG.BIN_MS > v.lastSeenMs || v.lastSeenMs >= v.tMs) throw new SessionError("INVALID_BIN_TIME");
    const k = v.traceId + "\x00" + v.tMs;
    if (keys.has(k)) throw new SessionError("DUPLICATE_BIN");
    keys.add(k);
  }
  for (const v of self) {
    if (v.quality === "unavailable" && v.positionM !== null ||
        v.quality !== "unavailable" && (v.positionM === null || v.horizontalAccuracyM === null)) throw new SessionError("INVALID_POSITION");
  }
  return {session, reorderedRecords: reordered};
}
export function bleBinEnd(callbackMs: number): number {
  if (!Number.isInteger(callbackMs) || callbackMs < 0) throw new SessionError("INVALID_TIME");
  return (Math.floor(callbackMs / CONFIG.BIN_MS) + 1) * CONFIG.BIN_MS;
}
export function acceptableRSSI(rssi: number): boolean {
  return Number.isFinite(rssi) && rssi >= -127 && rssi <= 20 && rssi !== 127 && rssi !== -128;
}
export function positionQuality(accuracyM: number | null, ageMs: number): "usable" | "coarse" | "unavailable" {
  if (accuracyM === null || accuracyM < 0 || !Number.isFinite(accuracyM) || ageMs > 5000) return "unavailable";
  if (accuracyM <= 20) return "usable";
  if (accuracyM <= 50) return "coarse";
  return "unavailable";
}
