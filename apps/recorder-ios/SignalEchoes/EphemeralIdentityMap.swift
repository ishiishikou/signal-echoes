import Foundation

/// OSから受け取ったUUIDはメモリ内だけで利用し、ログには記録しない。
final class EphemeralIdentityMap {
    private struct Item {
        var token: String
        var bornMs: Int
        var lastSeenMs: Int
    }
    private var items: [UUID: Item] = [:]

    func token(for osUUID: UUID, atMs: Int) -> String {
        prune(atMs: atMs)
        if var existing = items[osUUID],
           atMs - existing.bornMs < RecordingPolicy.tokenLifetimeMs,
           atMs - existing.lastSeenMs < RecordingPolicy.tokenSilenceMs {
            existing.lastSeenMs = atMs
            items[osUUID] = existing
            return existing.token
        }
        let token = "e-" + UUID().uuidString.lowercased()
        items[osUUID] = Item(token: token, bornMs: atMs, lastSeenMs: atMs)
        return token
    }
    func prune(atMs: Int) {
        items = items.filter {
            atMs - $0.value.bornMs < RecordingPolicy.tokenLifetimeMs &&
            atMs - $0.value.lastSeenMs < RecordingPolicy.tokenSilenceMs
        }
    }
    func reset() { items.removeAll() }
}