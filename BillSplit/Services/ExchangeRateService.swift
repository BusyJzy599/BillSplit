import Foundation

class ExchangeRateService {
    static let shared = ExchangeRateService()
    private let cacheKey = "cachedExchangeRate"
    private let dateKey = "cachedExchangeRateDate"
    private let fallbackRate = 7.2

    var currentRate: Double {
        if let cached = UserDefaults.standard.value(forKey: cacheKey) as? Double,
           let date = UserDefaults.standard.value(forKey: dateKey) as? Date,
           Calendar.current.isDateInToday(date) {
            return cached
        }
        return fallbackRate
    }

    func fetchLatest() async -> Double {
        // Return cached if already fetched today
        if let cached = UserDefaults.standard.value(forKey: cacheKey) as? Double,
           let date = UserDefaults.standard.value(forKey: dateKey) as? Date,
           Calendar.current.isDateInToday(date) {
            return cached
        }

        do {
            let url = URL(string: "https://prmjucdsuejtdxxyucxo.supabase.co/functions/v1/get-exchange-rate")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBybWp1Y2RzdWVqdGR4eHl1Y3hvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5NjM0MjUsImV4cCI6MjA5NTUzOTQyNX0.UgcwvOxXaUoOPyRwnIjnZz8_vkmwfLsZX25_nozhnFw", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let rate = json?["rate"] as? Double, rate > 5, rate < 10 {
                UserDefaults.standard.set(rate, forKey: cacheKey)
                UserDefaults.standard.set(Date(), forKey: dateKey)
                // Update Currency's static rate
                Currency.rateUSDToCNY = rate
                return rate
            }
        } catch {
            print("Exchange rate fetch failed: \(error)")
        }
        return fallbackRate
    }
}
