//
//  TriviaQuestion.swift
//  MuseumMate
//
//  A single multiple-choice art trivia question (GPT-generated).
//

import Foundation

struct TriviaQuestion: Codable, Equatable {
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String

    func isCorrect(_ index: Int) -> Bool { index == correctIndex }

    static let preview = TriviaQuestion(
        question: "Where is Vincent van Gogh's “Wheat Field with Cypresses” primarily held today?",
        options: [
            "The Metropolitan Museum of Art",
            "The Louvre",
            "The Uffizi Gallery",
            "The Prado"
        ],
        correctIndex: 0,
        explanation: "One version of the work is part of the European Paintings collection at The Met in New York."
    )
}
