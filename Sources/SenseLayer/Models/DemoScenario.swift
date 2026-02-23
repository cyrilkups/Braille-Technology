import Foundation

public enum DemoScenario: String, CaseIterable, Equatable {
    case bankFraud
    case momBirthday
    case overloadFilter

    public var focusCategory: MessageCategory {
        switch self {
        case .bankFraud:
            return .urgent
        case .momBirthday:
            return .personal
        case .overloadFilter:
            return .other
        }
    }

    public var messages: [Message] {
        switch self {
        case .bankFraud:
            return [
                Self.message(
                    id: "D7E5E028-2114-4A0C-9E64-2D3E5B0F0A01",
                    sender: "Bank Alert",
                    body: "Fraud alert: card ending 8842 charged $942.13 at 2:14 AM. Call the bank now.",
                    secondsFromBase: 0,
                    urgency: 0.99,
                    tone: .urgent,
                    category: .urgent
                ),
                Self.message(
                    id: "D7E5E028-2114-4A0C-9E64-2D3E5B0F0A02",
                    sender: "Security Team",
                    body: "A new sign-in was blocked from an unknown device.",
                    secondsFromBase: 60,
                    urgency: 0.88,
                    tone: .urgent,
                    category: .urgent
                ),
                Self.message(
                    id: "D7E5E028-2114-4A0C-9E64-2D3E5B0F0A03",
                    sender: "Mom",
                    body: "Call me when you are free.",
                    secondsFromBase: 120,
                    urgency: 0.30,
                    tone: .empathy,
                    category: .personal
                ),
                Self.message(
                    id: "D7E5E028-2114-4A0C-9E64-2D3E5B0F0A04",
                    sender: "PM",
                    body: "Standup moved to 10:15.",
                    secondsFromBase: 180,
                    urgency: 0.42,
                    tone: .calm,
                    category: .work
                ),
            ]

        case .momBirthday:
            return [
                Self.message(
                    id: "0D9F8E2A-6F40-4B3D-8E35-4A4D0BCB2201",
                    sender: "Mom",
                    body: "Birthday dinner is Sunday at 6 PM. I will bring cake.",
                    secondsFromBase: 0,
                    urgency: 0.46,
                    tone: .empathy,
                    category: .personal
                ),
                Self.message(
                    id: "0D9F8E2A-6F40-4B3D-8E35-4A4D0BCB2202",
                    sender: "Dad",
                    body: "Do not forget candles for Mom's birthday table.",
                    secondsFromBase: 60,
                    urgency: 0.34,
                    tone: .calm,
                    category: .personal
                ),
                Self.message(
                    id: "0D9F8E2A-6F40-4B3D-8E35-4A4D0BCB2203",
                    sender: "Bank Alert",
                    body: "Statement is ready to review.",
                    secondsFromBase: 120,
                    urgency: 0.22,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "0D9F8E2A-6F40-4B3D-8E35-4A4D0BCB2204",
                    sender: "PM",
                    body: "Draft agenda for Monday planning attached.",
                    secondsFromBase: 180,
                    urgency: 0.35,
                    tone: .calm,
                    category: .work
                ),
            ]

        case .overloadFilter:
            return [
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA01",
                    sender: "Deals",
                    body: "Daily discount digest #1",
                    secondsFromBase: 0,
                    urgency: 0.08,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA02",
                    sender: "Deals",
                    body: "Daily discount digest #2",
                    secondsFromBase: 15,
                    urgency: 0.08,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA03",
                    sender: "Retail Bot",
                    body: "Flash sale update #3",
                    secondsFromBase: 30,
                    urgency: 0.09,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA04",
                    sender: "News Feed",
                    body: "Morning brief #4",
                    secondsFromBase: 45,
                    urgency: 0.12,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA05",
                    sender: "Transit",
                    body: "Service reminder #5",
                    secondsFromBase: 60,
                    urgency: 0.14,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA06",
                    sender: "News Feed",
                    body: "Midday brief #6",
                    secondsFromBase: 75,
                    urgency: 0.12,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA07",
                    sender: "Calendar Bot",
                    body: "Reminder summary #7",
                    secondsFromBase: 90,
                    urgency: 0.10,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA08",
                    sender: "Deals",
                    body: "Daily discount digest #8",
                    secondsFromBase: 105,
                    urgency: 0.08,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA09",
                    sender: "Retail Bot",
                    body: "Flash sale update #9",
                    secondsFromBase: 120,
                    urgency: 0.09,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA0A",
                    sender: "News Feed",
                    body: "Evening brief #10",
                    secondsFromBase: 135,
                    urgency: 0.12,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA0B",
                    sender: "Promo",
                    body: "Weekly roundup #11",
                    secondsFromBase: 150,
                    urgency: 0.11,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA0C",
                    sender: "Promo",
                    body: "Weekly roundup #12",
                    secondsFromBase: 165,
                    urgency: 0.11,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA0D",
                    sender: "Security Team",
                    body: "Password changed successfully.",
                    secondsFromBase: 180,
                    urgency: 0.28,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA0E",
                    sender: "System",
                    body: "Backup completed overnight.",
                    secondsFromBase: 195,
                    urgency: 0.24,
                    tone: .calm,
                    category: .other
                ),
                Self.message(
                    id: "AF10D8A6-9605-4F6B-9D93-5EDB0167AA0F",
                    sender: "Boss",
                    body: "Can we sync tomorrow morning?",
                    secondsFromBase: 210,
                    urgency: 0.40,
                    tone: .calm,
                    category: .work
                ),
            ]
        }
    }

    private static let baseDate = Date(timeIntervalSince1970: 1_735_000_000)

    private static func message(
        id: String,
        sender: String,
        body: String,
        secondsFromBase: TimeInterval,
        urgency: Double,
        tone: Tone,
        category: MessageCategory
    ) -> Message {
        Message.clamped(
            id: UUID(uuidString: id)!,
            senderName: sender,
            body: body,
            timestamp: baseDate.addingTimeInterval(secondsFromBase),
            urgencyScore: urgency,
            tone: tone,
            category: category
        )
    }
}
