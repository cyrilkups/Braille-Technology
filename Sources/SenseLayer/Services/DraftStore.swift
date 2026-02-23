import Foundation

/// In-memory draft persistence keyed by conversation.
public struct DraftStore {
    private var drafts: [String: String] = [:]

    public init() {}

    public mutating func saveDraft(conversationKey: String, text: String) {
        drafts[conversationKey] = text
    }

    public func loadDraft(conversationKey: String) -> String? {
        drafts[conversationKey]
    }

    public mutating func clearDraft(conversationKey: String) {
        drafts.removeValue(forKey: conversationKey)
    }
}
