import Foundation

/// Read-only presentation wrapper around `Message`.
/// Adds computed fields derived from `CompressionService` without mutating the domain model.
struct MessagePresentation: Equatable, Hashable, Identifiable {
    let message: Message

    var id: UUID { message.id }

    var summary: String {
        CompressionService.summary(body: message.body)
    }

    var conversationKey: String {
        message.senderName
    }
}
