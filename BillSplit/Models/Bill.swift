import Foundation

// MARK: - Bill Category

enum BillCategory: String, CaseIterable, Codable {
    case dinner
    case coffee
    case transport
    case housing
    case shopping
    case entertainment
    case travel
    case medical
    case education
    case gift
    case utilities
    case other

    var icon: String {
        switch self {
        case .dinner: return "🍽️"
        case .coffee: return "☕"
        case .transport: return "🚗"
        case .housing: return "🏠"
        case .shopping: return "🛍️"
        case .entertainment: return "🎮"
        case .travel: return "✈️"
        case .medical: return "🏥"
        case .education: return "📚"
        case .gift: return "🎁"
        case .utilities: return "💡"
        case .other: return "💰"
        }
    }

    func displayName(_ locale: AppLocale) -> String {
        switch self {
        case .dinner: return locale == .zh ? "晚餐" : "Dinner"
        case .coffee: return locale == .zh ? "咖啡饮料" : "Coffee"
        case .transport: return locale == .zh ? "交通" : "Transport"
        case .housing: return locale == .zh ? "住宿" : "Housing"
        case .shopping: return locale == .zh ? "购物" : "Shopping"
        case .entertainment: return locale == .zh ? "娱乐" : "Entertainment"
        case .travel: return locale == .zh ? "旅行" : "Travel"
        case .medical: return locale == .zh ? "医疗" : "Medical"
        case .education: return locale == .zh ? "教育" : "Education"
        case .gift: return locale == .zh ? "礼物" : "Gift"
        case .utilities: return locale == .zh ? "日用品" : "Utilities"
        case .other: return locale == .zh ? "其他" : "Other"
        }
    }
}

// MARK: - Bill

struct Bill: Codable, Identifiable, Equatable {
    var id: Int?
    var groupId: Int
    var payerId: String
    var amount: Double           // stored in CNY
    var description: String
    var participantIds: [String]
    var currency: String         // "usd" or "cny" — input currency
    var exchangeRate: Double     // rate used: input → CNY
    var category: String         // BillCategory rawValue
    var createdAt: Date

    var categoryEnum: BillCategory { BillCategory(rawValue: category) ?? .other }

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
        case category
        case createdAt = "created_at"
    }
}
