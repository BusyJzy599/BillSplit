import SwiftUI

enum Currency: String, CaseIterable {
    case usd
    case cny

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .cny: return "¥"
        }
    }

    var name: String {
        switch self {
        case .usd: return "美元 (USD)"
        case .cny: return "人民币 (CNY)"
        }
    }

    var toUSD: Double {
        switch self {
        case .usd: return 1.0
        case .cny: return 0.14   // 1 CNY ≈ 0.14 USD
        }
    }

    static let exchangeRate: Double = 7.2  // 1 USD = 7.2 CNY (approx)

    func convert(_ amount: Double, to target: Currency) -> Double {
        let inUSD = amount * self.toUSD
        switch target {
        case .usd: return inUSD
        case .cny: return inUSD * Currency.exchangeRate
        }
    }
}

class CurrencySettings: ObservableObject {
    static let shared = CurrencySettings()

    @AppStorage("selectedCurrency") var selectedCurrency: String = Currency.usd.rawValue

    var current: Currency {
        Currency(rawValue: selectedCurrency) ?? .usd
    }

    func formatted(_ amountInCNY: Double) -> String {
        let converted = Currency.cny.convert(amountInCNY, to: current)
        return String(format: "\(current.symbol)%.2f", converted)
    }
}
