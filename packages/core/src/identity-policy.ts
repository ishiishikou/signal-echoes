import { CONFIG } from "./config";
export type EphemeralRecord = { token: string; bornMs: number; lastSeenMs: number };
export function expires(record: EphemeralRecord, nowMs: number): boolean {
  return nowMs - record.bornMs >= CONFIG.TRACE_LIFETIME_MS ||
         nowMs - record.lastSeenMs >= CONFIG.TRACE_SILENCE_MS;
}
export function clearOnPause<T>(records: Map<string,T>): void { records.clear(); }
