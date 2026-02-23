import Foundation

/// Rule-based message classification and tone detection.
///
/// Category precedence: urgent > work > personal > other.
/// Tone precedence:     anger > empathy > urgent > calm.
public struct CompressionService {

    // MARK: - Category keywords

    private static let urgentCategoryKeywords = [
        "urgent", "asap", "deadline", "due", "fraud", "bank", "immediately"
    ]

    private static let workKeywords = [
        "meeting", "client", "standup", "project"
    ]

    private static let personalKeywords = [
        "mom", "dad", "family", "love", "dinner"
    ]

    // MARK: - Tone keywords / phrases

    private static let angerPhrases = [
        "furious", "livid", "outraged", "unacceptable", "ridiculous",
        "damn", "hell", "pissed", "sick of", "fed up",
        "how dare", "what the"
    ]

    private static let angerNegativeWords = [
        "terrible", "awful", "horrible", "worst", "hate",
        "angry", "frustrated", "annoyed", "disgusted", "pathetic"
    ]

    private static let empathyPhrases = [
        "sorry", "thinking of you", "here for you", "praying",
        "condolences", "my heart goes out", "take care", "wishing you well"
    ]

    private static let urgentToneKeywords = [
        "asap", "now", "immediately", "deadline", "right away", "hurry"
    ]

    // MARK: - Category

    public static func categorize(body: String, senderName: String) -> MessageCategory {
        let text = "\(body) \(senderName)".lowercased()

        if urgentCategoryKeywords.contains(where: { text.contains($0) }) {
            return .urgent
        }
        if workKeywords.contains(where: { text.contains($0) }) {
            return .work
        }
        if personalKeywords.contains(where: { text.contains($0) }) {
            return .personal
        }
        return .other
    }

    // MARK: - Tone

    public static func tone(body: String) -> Tone {
        let text = body.lowercased()

        if isAngry(text) {
            return .anger
        }
        if empathyPhrases.contains(where: { text.contains($0) }) {
            return .empathy
        }
        if urgentToneKeywords.contains(where: { text.contains($0) }) {
            return .urgent
        }
        return .calm
    }

    private static func isAngry(_ text: String) -> Bool {
        if angerPhrases.contains(where: { text.contains($0) }) {
            return true
        }
        let hasExclamation = text.contains("!!")
        let hasNegative = angerNegativeWords.contains(where: { text.contains($0) })
        return hasExclamation && hasNegative
    }

    // MARK: - Urgency score

    private static let boostKeywords = ["now", "today", "deadline", "fraud"]
    private static let boostPerKeyword = 0.1

    public static func urgencyScore(body: String, category: MessageCategory) -> Double {
        let baseline: Double
        switch category {
        case .urgent:   baseline = 0.8
        case .work:     baseline = 0.5
        case .personal: baseline = 0.3
        case .other:    baseline = 0.2
        }

        let text = body.lowercased()
        let hits = boostKeywords.filter { text.contains($0) }.count
        let score = baseline + Double(hits) * boostPerKeyword

        return min(max(score, 0), 1)
    }

    // MARK: - Summary

    public static func summary(body: String, maxChars: Int = 120) -> String {
        let single = body
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespaces)

        guard single.count > maxChars else { return single }

        let ellipsis: Character = "\u{2026}"
        let truncated = single.prefix(maxChars - 1)
        return String(truncated) + String(ellipsis)
    }
}
