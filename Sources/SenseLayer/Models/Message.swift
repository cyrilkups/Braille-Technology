import Foundation

public struct Message: Equatable, Hashable {
    public let id: UUID
    public let senderName: String
    public let body: String
    public let timestamp: Date
    public private(set) var urgencyScore: Double
    public let tone: Tone
    public var isRead: Bool
    public let category: MessageCategory

    public init?(
        id: UUID = UUID(),
        senderName: String,
        body: String,
        timestamp: Date = Date(),
        urgencyScore: Double,
        tone: Tone,
        isRead: Bool = false,
        category: MessageCategory
    ) {
        guard (0...1).contains(urgencyScore) else { return nil }
        self.id = id
        self.senderName = senderName
        self.body = body
        self.timestamp = timestamp
        self.urgencyScore = urgencyScore
        self.tone = tone
        self.isRead = isRead
        self.category = category
    }

    /// Clamps the given score into the 0…1 range and returns a valid `Message`.
    public static func clamped(
        id: UUID = UUID(),
        senderName: String,
        body: String,
        timestamp: Date = Date(),
        urgencyScore: Double,
        tone: Tone,
        isRead: Bool = false,
        category: MessageCategory
    ) -> Message {
        let clamped = min(max(urgencyScore, 0), 1)
        // Safe to force-unwrap: clamped value is always in 0...1.
        return Message(
            id: id,
            senderName: senderName,
            body: body,
            timestamp: timestamp,
            urgencyScore: clamped,
            tone: tone,
            isRead: isRead,
            category: category
        )!
    }
}
