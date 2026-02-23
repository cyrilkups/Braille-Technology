import Foundation

public protocol MessageRepository {
    mutating func loadMessages() -> [Message]
    mutating func markRead(id: UUID)
    func isRead(id: UUID) -> Bool
}

/// In-memory repository backed by `MockMessageFactory`.
/// Applies `CompressionService` to populate category, tone, and urgencyScore
/// on first load, then caches the result. Read-status persists across calls.
public struct InMemoryMessageRepository: MessageRepository {
    private let seed: Int
    private let count: Int
    private var readIDs: Set<UUID> = []
    private var cached: [Message]?

    public init(seed: Int = 42, count: Int = 15) {
        self.seed = seed
        self.count = count
    }

    public mutating func loadMessages() -> [Message] {
        if cached == nil {
            cached = buildMessages()
        }
        return cached!.map { msg in
            var m = msg
            if readIDs.contains(m.id) {
                m.isRead = true
            }
            return m
        }
    }

    public mutating func markRead(id: UUID) {
        readIDs.insert(id)
    }

    public func isRead(id: UUID) -> Bool {
        readIDs.contains(id)
    }

    private func buildMessages() -> [Message] {
        let raw = MockMessageFactory.generate(seed: seed, count: count)
        return raw.map { msg in
            let category = CompressionService.categorize(body: msg.body, senderName: msg.senderName)
            let tone = CompressionService.tone(body: msg.body)
            let score = CompressionService.urgencyScore(body: msg.body, category: category)
            return Message.clamped(
                id: msg.id,
                senderName: msg.senderName,
                body: msg.body,
                timestamp: msg.timestamp,
                urgencyScore: score,
                tone: tone,
                category: category
            )
        }
    }
}
