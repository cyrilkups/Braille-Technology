import Foundation

/// Navigation context for the Navigate mode.
public enum NavigateContext: Equatable {
  case apps
  case conversations(appID: String)
  case genericList(title: String, items: [String])
}

/// Reading context for the Read mode.
public struct ReadContext: Equatable {
  public let message: Message
  public let appName: String?
  public let hapticSignature: HapticSignature

  public init(message: Message, appName: String? = nil, hapticSignature: HapticSignature? = nil) {
    self.message = message
    self.appName = appName
    // Derive signature from message category, or use provided one
    self.hapticSignature = hapticSignature ?? HapticSignature.from(category: message.category)
  }
}

/// The three main modes of the SenseLayer UI.
public enum SenseMode: Equatable {
  /// Home mode: shows urgent count, top summary, quick actions.
  case home

  /// Navigate mode: list navigation (apps, conversations, items).
  case navigate(context: NavigateContext)

  /// Read mode: message reader and reply composer.
  case read(context: ReadContext)
}
