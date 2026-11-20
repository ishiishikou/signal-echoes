import { z } from "zod";
const n = z.number().finite();
const ti = z.number().int().min(0).max(900000);
const name = z.string().min(1).max(64);
const optionalN = n.nullable();
const position = z.tuple([n.min(-10000).max(10000), n.min(-10000).max(10000), n.min(-10000).max(10000)]);
export const bleBinSchema = z.object({
  tMs: ti, traceId: name, rssiMedianDbm: n.min(-127).max(20),
  sampleCount: z.number().int().min(1).max(1000000), lastSeenMs: ti
}).strict();
export const selfSampleSchema = z.object({
  tMs: ti, segmentId: name, source: z.enum(["synthetic", "coreLocation"]),
  positionM: position.nullable(), horizontalAccuracyM: n.min(0).max(100000).nullable(),
  ageMs: ti, quality: z.enum(["usable", "coarse", "unavailable"]),
  headingDeg: n.min(0).lt(360).nullable(), headingAccuracyDeg: n.min(0).max(180).nullable(),
  stepsDelta: z.number().int().min(0).max(1000000).nullable(),
  stepsIntervalMs: ti.nullable(), floor: z.null()
}).strict();
export const statusEventSchema = z.object({
  tMs: ti, state: z.enum(["recording", "paused", "finished", "interrupted", "degraded"]),
  reason: z.enum(["user_start","user_stop","heartbeat","app_inactive","bluetooth_off","permission_denied",
    "location_unavailable","clock_discontinuity","overflow","storage_limit","write_failed",
    "recovered_interruption","resumed","thermal"]),
  scanActive: z.boolean(), droppedCount: z.number().int().min(0).max(1000000),
}).strict();
export const sessionSchema = z.object({
  schema: z.literal("signal-echoes.session"), version: z.literal(1),
  provenance: z.enum(["synthetic","measured"]),
  sessionId: name, durationMs: ti, coordinateFrame: z.literal("local-east-up-south-m"),
  seed: z.number().int().min(0).max(4294967295),
  capture: z.object({
    mode: z.enum(["synthetic","foreground"]), serviceFilter: z.enum(["none","configured"]),
    binMs: z.literal(1000), completion: z.enum(["complete","interrupted"])
  }).strict(),
  observations: z.object({
    ble: z.array(bleBinSchema).max(100000),
    self: z.array(selfSampleSchema).max(100000),
    status: z.array(statusEventSchema).max(100000)
  }).strict()
}).strict();
export type ParsedSession = z.infer<typeof sessionSchema>;
