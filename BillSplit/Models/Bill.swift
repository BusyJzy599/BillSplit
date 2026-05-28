import Foundation

struct Bill: Codable, Identifiable {
    var id: Int?
    var groupId: Int
    var payerId: String
    var amount: Double           // stored in CNY
    var description: String
    var participantIds: [String]
    var currency: String         // "usd" or "cny" — input currency
    var exchangeRate: Double     // rate used: input → CNY
    var createdAt: Date

    /// Display amount in user's preferred currency, converting from stored CNY
    func displayAmount(displayCurrency: Currency) -> String {
        let inCNY = amount
        let converted = Currency.cny.convert(inCNY, to: displayCurrency)
        return String(format: "\(displayCurrency.symbol)%.2f", converted)
    }

    /// Display original input amount in the bill's original currency
    var displayOriginal: String {
        guard let cur = Currency(rawValue: currency) else {
            return String(format: "¥%.2f", amount)
        }
        let original = exchangeRate > 0 ? amount / exchangeRate : amount
        return String(format: "\(cur.symbol)%.2f", original)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case payerId = "payer_id"
        case amount
        case description
        case participantIds = "participant_ids"
        case currency
        case exchangeRate = "exchange_rate"
        case createdAt = "created_at"
    }
}
