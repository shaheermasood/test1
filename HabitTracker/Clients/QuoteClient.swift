import Foundation
import Dependencies

// MARK: - Quote

public struct Quote: Equatable, Sendable {
    public let text: String
    public let author: String?

    public init(text: String, author: String? = nil) {
        self.text = text
        self.author = author
    }
}

// MARK: - Quote Client

public struct QuoteClient: Sendable {
    public var getDailyQuote: @Sendable (String) async -> Quote

    public init(
        getDailyQuote: @escaping @Sendable (String) async -> Quote
    ) {
        self.getDailyQuote = getDailyQuote
    }
}

// MARK: - Dependency

extension QuoteClient: DependencyKey {
    public static let liveValue = QuoteClient(
        getDailyQuote: { dateKey in
            // Deterministic quote based on date
            let quotes = zenCoachQuotes
            let hash = dateKey.hashValue
            let index = abs(hash) % quotes.count
            return quotes[index]
        }
    )

    public static let testValue = QuoteClient(
        getDailyQuote: { _ in
            Quote(text: "One step at a time", author: nil)
        }
    )
}

extension DependencyValues {
    public var quoteClient: QuoteClient {
        get { self[QuoteClient.self] }
        set { self[QuoteClient.self] = newValue }
    }
}

// MARK: - Zen Coach Quotes

private let zenCoachQuotes: [Quote] = [
    Quote(text: "Small steps, taken consistently, create lasting change", author: nil),
    Quote(text: "Progress, not perfection", author: nil),
    Quote(text: "What you do today shapes who you become tomorrow", author: nil),
    Quote(text: "Be gentle with yourself; growth takes time", author: nil),
    Quote(text: "Each moment is a fresh start", author: nil),
    Quote(text: "Your routine is a love letter to your future self", author: nil),
    Quote(text: "Consistency beats intensity", author: nil),
    Quote(text: "Trust the process, even on the hard days", author: nil),
    Quote(text: "You're building something meaningful, one day at a time", author: nil),
    Quote(text: "Rest is part of the rhythm, not a failure", author: nil),
    Quote(text: "Every habit is a vote for the person you want to become", author: nil),
    Quote(text: "Start where you are. Use what you have. Do what you can", author: nil),
    Quote(text: "The path is made by walking", author: nil),
    Quote(text: "Gentle persistence opens all doors", author: nil),
    Quote(text: "Today is another chance to care for yourself", author: nil),
    Quote(text: "You don't have to be perfect to make progress", author: nil),
    Quote(text: "Celebrate the small wins—they add up", author: nil),
    Quote(text: "Your effort matters, even when it feels small", author: nil),
    Quote(text: "Showing up is half the battle", author: nil),
    Quote(text: "Be patient with your process", author: nil),
    Quote(text: "The journey of a thousand miles begins with a single step", author: "Lao Tzu"),
    Quote(text: "What we do every day matters more than what we do once in a while", author: nil),
    Quote(text: "You are exactly where you need to be", author: nil),
    Quote(text: "Growth happens in the quiet moments", author: nil),
    Quote(text: "Your routine is your foundation", author: nil),
    Quote(text: "Take a breath. You've got this", author: nil),
    Quote(text: "Every sunrise brings new opportunities", author: nil),
    Quote(text: "Be kind to yourself today", author: nil),
    Quote(text: "Your habits shape your life", author: nil),
    Quote(text: "One percent better every day", author: nil)
]
