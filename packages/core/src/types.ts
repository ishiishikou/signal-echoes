export type Vec3 = [number, number, number];
export type BleBin = { tMs: number; traceId: string; rssiMedianDbm: number; sampleCount: number; lastSeenMs: number };
export type SelfSample = {
  tMs: number; segmentId: string; source: "synthetic" | "coreLocation"; positionM: Vec3 | null;
  horizontalAccuracyM: number | null; ageMs: number;
  quality: "usable" | "coarse" | "unavailable";
  headingDeg: number | null; headingAccuracyDeg: number | null;
  stepsDelta: number | null; stepsIntervalMs: number | null; floor: null;
};
export type RecordingState = "recording" | "paused" | "finished" | "interrupted" | "degraded";
export type StatusEvent = { tMs: number; state: RecordingState; reason: string; scanActive: boolean; droppedCount: number };
export type Session = {
  schema: "signal-echoes.session"; version: 1; provenance: "synthetic" | "measured";
  sessionId: string; durationMs: number; coordinateFrame: "local-east-up-south-m"; seed: number;
  capture: { mode: "synthetic" | "foreground"; serviceFilter: "none" | "configured"; binMs: 1000; completion: "complete" | "interrupted" };
  observations: { ble: BleBin[]; self: SelfSample[]; status: StatusEvent[] };
};
export type Trend = "rising" | "falling" | "stable" | "variable" | "unknown";
export type SignalAnalysis = {
  smoothRssiDbm: number | null; trend: Trend; quality: "sufficient" | "moderate" | "insufficient";
  validBins: number; slopeDbPerSec: number | null; residualMADDb: number | null;
  ageMs: number; sourceDirection: null; sourceDistanceM: null; physicalMotion: "unknown";
};
export type Particle = { id: string; virtualPosition: Vec3; intensity: number; opacity: number; stale: boolean; trend: Trend; quality: SignalAnalysis["quality"]; rssi: number | null; anchorBasis: "observed_self" | "interpolated_self" | "fixed_stage"; };
export type RenderFrame = {
  atMs: number; self: Vec3 | null; anchorBasis: Particle["anchorBasis"]; headingDeg: number | null;
  particles: Particle[]; activeTraces: number; renderedTraces: number;
  scanState: "active" | "paused" | "unavailable"; positionQuality: "usable" | "coarse" | "unavailable";
  statusReason: string; selectedTrend: Record<Trend, number>;
};
