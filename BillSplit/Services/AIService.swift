import Foundation
import Supabase

struct AIExtractedItem: Codable, Identifiable {
    var id = UUID()
    var description: String
    var amount: Double
    var isShared: Bool = true
    var selected: Bool = true
}

class AIService {
    static let shared = AIService()

    var isConfigured: Bool { true }  // Edge function handles the key

    func extractItems(from rawText: String) async throws -> [AIExtractedItem] {
        let response: [String: [AIExtractedItem]] = try await supabase.functions
            .invoke("ai-parse-receipt", options: .init(body: ["rawText": rawText]))

        return response["items"] ?? []
    }
}
