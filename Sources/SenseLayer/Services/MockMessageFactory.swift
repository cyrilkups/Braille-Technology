import Foundation

/// Generates deterministic mock messages for testing and previews.
/// Same `seed` + `count` always produces identical output.
struct MockMessageFactory {

    private struct SeededRNG: RandomNumberGenerator {
        private var state: UInt64

        init(seed: Int) {
            state = UInt64(bitPattern: Int64(seed))
        }

        mutating func next() -> UInt64 {
            // SplitMix64
            state &+= 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
            z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
    }

    private static let senders = [
        "Mom", "Dad", "Jamie", "Dr. Patel", "Landlord",
        "Boss", "Alice Chen", "Bank Alert", "HR Dept", "Priya"
    ]

    private static let bodies = [
        "The rent is due tomorrow, please don't forget the deadline.",
        "Hey, just checking in — dinner tonight at 7?",
        "Your bank account balance is below the minimum threshold.",
        "Meeting moved to 3 PM, mandatory attendance required.",
        "Mom called twice, she says it's important. Call her back.",
        "Quarterly review is this Friday, prepare your slides by Thursday.",
        "Happy birthday! Hope you have a wonderful day.",
        "Severe weather alert: tornado warning in your area until 6 PM.",
        "Can you pick up groceries on the way home? We need milk.",
        "Your prescription is ready for pickup at the pharmacy.",
        "Final notice: your insurance payment is overdue.",
        "Lunch tomorrow? I found a great new place downtown.",
        "The project deadline has been extended to next Monday.",
        "Emergency: server outage detected, all hands on deck.",
        "Don't forget — dentist appointment at 10 AM tomorrow.",
        "I miss you. Let's catch up this weekend over coffee.",
        "Board meeting notes attached. Review before end of day.",
        "Your flight has been delayed by 2 hours. New departure: 9 PM.",
        "Can you cover my shift on Saturday? I owe you one.",
        "Congratulations on the promotion! Well deserved."
    ]

    static func generate(seed: Int, count: Int) -> [Message] {
        var rng = SeededRNG(seed: seed)
        let epoch = Date(timeIntervalSince1970: 1_700_000_000)

        return (0..<count).map { _ in
            let senderIdx = Int(rng.next() % UInt64(senders.count))
            let bodyIdx = Int(rng.next() % UInt64(bodies.count))
            let uuidBits0 = rng.next()
            let uuidBits1 = rng.next()
            let uuid = uuidFromBits(hi: uuidBits0, lo: uuidBits1)
            let offsetSeconds = Double(rng.next() % 604_800) // up to 7 days
            let timestamp = epoch.addingTimeInterval(offsetSeconds)

            return Message.clamped(
                id: uuid,
                senderName: senders[senderIdx],
                body: bodies[bodyIdx],
                timestamp: timestamp,
                urgencyScore: 0.5,
                tone: .calm,
                category: .other
            )
        }
    }

    private static func uuidFromBits(hi: UInt64, lo: UInt64) -> UUID {
        var hi = hi
        var lo = lo
        // Set version 4 and variant bits for RFC 4122 compliance
        hi = (hi & 0xFFFFFFFF_FFFF0FFF) | 0x00000000_00004000
        lo = (lo & 0x3FFFFFFF_FFFFFFFF) | 0x80000000_00000000
        let bytes = (
            UInt8(truncatingIfNeeded: hi >> 56),
            UInt8(truncatingIfNeeded: hi >> 48),
            UInt8(truncatingIfNeeded: hi >> 40),
            UInt8(truncatingIfNeeded: hi >> 32),
            UInt8(truncatingIfNeeded: hi >> 24),
            UInt8(truncatingIfNeeded: hi >> 16),
            UInt8(truncatingIfNeeded: hi >> 8),
            UInt8(truncatingIfNeeded: hi),
            UInt8(truncatingIfNeeded: lo >> 56),
            UInt8(truncatingIfNeeded: lo >> 48),
            UInt8(truncatingIfNeeded: lo >> 40),
            UInt8(truncatingIfNeeded: lo >> 32),
            UInt8(truncatingIfNeeded: lo >> 24),
            UInt8(truncatingIfNeeded: lo >> 16),
            UInt8(truncatingIfNeeded: lo >> 8),
            UInt8(truncatingIfNeeded: lo)
        )
        return UUID(uuid: bytes)
    }
}
