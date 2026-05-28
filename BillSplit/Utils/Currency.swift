import SwiftUI

enum Currency: String, CaseIterable {
    case usd
    case cny

    var symbol: String { self == .usd ? "$" : "¥" }
    var name: String { self == .usd ? "USD" : "CNY" }

    static let rateUSDToCNY: Double = 7.2

    /// Convert amount FROM this currency TO target currency
    func convert(_ amount: Double, to target: Currency) -> Double {
        if self == target { return amount }
        if self == .usd && target == .cny { return amount * Currency.rateUSDToCNY }
        if self == .cny && target == .usd { return amount / Currency.rateUSDToCNY }
        return amount
    }
}

class CurrencySettings: ObservableObject {
    static let shared = CurrencySettings()

    @AppStorage("selectedCurrency") var selectedCurrency: String = Currency.usd.rawValue

    var current: Currency { Currency(rawValue: selectedCurrency) ?? .usd }

    func formatted(_ amountInCNY: Double) -> String {
        let converted = Currency.cny.convert(amountInCNY, to: current)
        return String(format: "\(current.symbol)%.2f", converted)
    }
}
