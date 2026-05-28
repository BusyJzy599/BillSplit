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

    private let endpoint = "https://api.deepseek.com/chat/completions"
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "deepseek_api_key") ?? ""
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    func extractItems(from rawText: String) async throws -> [AIExtractedItem] {
        guard isConfigured else { throw AIError.noAPIKey }

        let prompt = """
        You are a receipt parser. Extract all purchased items from this receipt text.
        Return ONLY a JSON array. Each item: {"description": "item name", "amount": price as number, "isShared": true}.
        If the receipt has a total line, ignore it. Only extract individual items.
        If an item has no clear price, set amount to 0.
        Receipt text:
        \(rawText)
        """

        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [[
                "role": "user",
                "content": prompt
            ]],
            "temperature": 0.1,
            "max_tokens": 1000
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseFailed
        }

        // Extract JSON from response
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else { throw AIError.parseFailed }
        let items = try JSONDecoder().decode([AIExtractedItem].self, from: jsonData)
        return items
    }
}

enum AIError: LocalizedError {
    case noAPIKey
    case parseFailed
    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "DeepSeek API Key not set. Add it in Profile > Settings."
        case .parseFailed: return "Failed to parse AI response."
        }
    }
}
