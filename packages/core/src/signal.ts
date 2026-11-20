import type { BleBin, SignalAnalysis } from "./types";
import { CONFIG } from "./config";
export function median(xs: number[]): number {
  if (!xs.length) throw new Error("EMPTY_MEDIAN");
  const ys = xs.slice().sort((a, b) => a - b);
  const h = ys.length >> 1;
  return ys.length % 2 ? ys[h] : (ys[h-1] + ys[h])/2;
}
export function fnv1a32(s: string): number {
  let h = 2166136261;
  for (const b of new TextEncoder().encode(s)) h = Math.imul(h ^ b, 16777619) >>> 0;
  return h;
}
export function analyzeTrace(bins: BleBin[], atMs: number): SignalAnalysis | null {
  const past = bins.filter(b => b.tMs <= atMs);
  if (!past.length) return null;
  const latest = past[past.length - 1];
  const ageMs = Math.max(0, atMs - latest.lastSeenMs);
  const smooth = past.filter(b => b.tMs > atMs - CONFIG.SMOOTH_WINDOW);
  const smoothRssiDbm = smooth.length ? median(smooth.map(b => b.rssiMedianDbm)) : null;
  const recent = past.filter(b => b.tMs > atMs - CONFIG.TREND_WINDOW);
  let trend: SignalAnalysis["trend"] = "unknown";
  let quality: SignalAnalysis["quality"] = "insufficient";
  let slopeDbPerSec: number | null = null, residualMADDb: number | null = null;
  const gaps = recent.length ? [
    Math.max(0,recent[0].tMs - (Math.floor((atMs - CONFIG.TREND_WINDOW) / 1000) * 1000 + 1000)),
    ...recent.slice(1).map((v,i) => v.tMs - recent[i].tMs - 1000),
    Math.floor(atMs / 1000) * 1000 - recent[recent.length-1].tMs
  ] : [CONFIG.TREND_WINDOW];
  const maxGap = Math.max(0, ...gaps);
  if (recent.length >= CONFIG.MIN_BINS &&
      recent[recent.length - 1].tMs - recent[0].tMs >= CONFIG.MIN_SPAN &&
      maxGap <= CONFIG.MAX_GAP_MS && ageMs <= CONFIG.FRESH_MS) {
    const slopes: number[] = [];
    for (let i = 0; i < recent.length; i++) for (let j = i+1; j < recent.length; j++)
      slopes.push((recent[j].rssiMedianDbm-recent[i].rssiMedianDbm) /
                  ((recent[j].tMs-recent[i].tMs)/1000));
    slopeDbPerSec = median(slopes);
    const intercept = median(recent.map(b => b.rssiMedianDbm - slopeDbPerSec! * b.tMs/1000));
    const residual = recent.map(b => b.rssiMedianDbm - slopeDbPerSec! * b.tMs/1000 - intercept);
    const residualCenter = median(residual);
    residualMADDb = median(residual.map(x => Math.abs(x - residualCenter)));
    const net = recent[recent.length-1].rssiMedianDbm - recent[0].rssiMedianDbm;
    quality = residualMADDb > CONFIG.MAX_MAD ? "insufficient" :
      recent.length === 10 ? "sufficient" : "moderate";
    if (residualMADDb <= CONFIG.MAX_MAD) {
      if (slopeDbPerSec >= CONFIG.SLOPE_THRESHOLD && net >= CONFIG.NET_CHANGE) trend = "rising";
      else if (slopeDbPerSec <= -CONFIG.SLOPE_THRESHOLD && net <= -CONFIG.NET_CHANGE) trend = "falling";
      else if (Math.abs(slopeDbPerSec) < CONFIG.SLOPE_THRESHOLD && Math.abs(net) < CONFIG.NET_CHANGE) trend = "stable";
      else trend = "variable";
    }
  }
  return { smoothRssiDbm, trend, quality, validBins: recent.length, slopeDbPerSec, residualMADDb, ageMs,
    sourceDirection:null, sourceDistanceM:null, physicalMotion:"unknown" };
}
