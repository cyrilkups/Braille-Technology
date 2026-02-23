import Foundation

public protocol SendService: Sendable {
    func send(conversationKey: String, text: String) async throws
}

/// Mock sender with a configurable result.
public struct MockSendService: SendService {
    public enum Mode: Sendable {
        case success
        case failure
    }

    public struct SendError: Error, Equatable {}

    public var mode: Mode

    public init(mode: Mode) { self.mode = mode }

    public func send(conversationKey: String, text: String) async throws {
        if mode == .failure {
            throw SendError()
        }
    }
}
