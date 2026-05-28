import Foundation

struct AIExtractedItem: Codable, Identifiable {
    var id = UUID()
    var description: String
    var amount: Double
    var isShared: Bool = true
    var selected: Bool = true
}

class AIService {
    static let shared = AIService()

    var isConfigured: Bool { true }

    func extractItems(from rawText: String) async throws -> [AIExtractedItem] {
        let url = URL(string: "https://prmjucdsuejtdxxyucxo.supabase.co/functions/v1/ai-parse-receipt")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Use anon key for Edge Function auth
        request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBybWp1Y2RzdWVqdGR4eHl1Y3hvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5NjM0MjUsImV4cCI6MjA5NTUzOTQyNX0.UgcwvOxXaUoOPyRwnIjnZz8_vkmwfLsZX25_nozhnFw", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["rawText": rawText])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw AIError.apiFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let itemsArray = json?["items"] as? [[String: Any]] else {
            throw AIError.parseFailed
        }

        return itemsArray.compactMap { dict in
            guard let desc = dict["description"] as? String else { return nil }
            let amt = (dict["amount"] as? Double) ?? (dict["amount"] as? Int).map(Double.init) ?? 0
            let shared = dict["isShared"] as? Bool ?? true
            return AIExtractedItem(description: desc, amount: amt, isShared: shared, selected: true)
        }
    }
}

enum AIError: LocalizedError {
    case apiFailed
    case parseFailed
    var errorDescription: String? {
        switch self {
        case .apiFailed: return "AI service unavailable"
        case .parseFailed: return "Failed to parse AI response"
        }
    }
}
