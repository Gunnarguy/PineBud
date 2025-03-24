// MARK: - SearchModels.swift
import Foundation

struct SearchResults {
    let query: String
    let answer: String
    let sources: [SourceResult]
    let timestamp: Date = Date()
}

struct SourceResult: Identifiable {
    let id: String
    let source: String
    let text: String
    let score: Double
}
