import type { SelfSample, Vec3 } from "./types";
export type SelfAt = { position: Vec3 | null; basis:"observed_self"|"interpolated_self"|"fixed_stage"; quality:"usable"|"coarse"|"unavailable"; headingDeg:number|null };
export function selfAt(samples: SelfSample[], atMs: number): SelfAt {
  let before: SelfSample | null = null, after: SelfSample | null = null;
  for (const s of samples) {
    if (s.tMs <= atMs) before = s;
    if (s.tMs >= atMs) { after = s; break; }
  }
  const absent: SelfAt = {position:null,basis:"fixed_stage",quality:before?.quality ?? "unavailable",headingDeg:null};
  if (before?.tMs === atMs && before.quality === "usable" && before.positionM)
    return {position:before.positionM,basis:"observed_self",quality:"usable",headingDeg:before.headingDeg};
  if (!before || !after || before.quality !== "usable" || after.quality !== "usable" ||
      !before.positionM || !after.positionM || before.segmentId !== after.segmentId ||
      after.tMs-before.tMs > 5000 || after.tMs <= before.tMs) return absent;
  const t = (atMs-before.tMs) / (after.tMs-before.tMs);
  return {position:before.positionM.map((v,i) => v + (after!.positionM![i]-v)*t) as Vec3,
    basis:"interpolated_self",quality:"usable",headingDeg:before.headingDeg};
}
export function makePathSegments(samples: SelfSample[]): Vec3[][] {
  const result: Vec3[][] = []; let current: Vec3[] = []; let prev: SelfSample|null = null;
  for (const sample of samples) {
    if (sample.quality !== "usable" || !sample.positionM) {
      if (current.length) result.push(current);
      current = []; prev = null; continue;
    }
    if (prev && (sample.segmentId !== prev.segmentId || sample.tMs - prev.tMs > 5000)) {
      if (current.length) result.push(current);
      current = [];
    }
    current.push(sample.positionM);
    prev = sample;
  }
  if (current.length) result.push(current);
  return result;
}
