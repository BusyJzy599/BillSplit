import Vision
import UIKit

class OCRService {
    static let shared = OCRService()

    func recognizeText(from image: UIImage) async throws -> [ReceiptItem] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let items = self.parseObservations(observations)
                continuation.resume(returning: items)
            }

            request.recognitionLevel = .fast
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
            request.minimumTextHeight = 0.01

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseObservations(_ observations: [VNRecognizedTextObservation]) -> [ReceiptItem] {
        var items: [ReceiptItem] = []

        let sorted = observations.sorted { obs1, obs2 in
            let y1 = obs1.boundingBox.origin.y + obs1.boundingBox.height
            let y2 = obs2.boundingBox.origin.y + obs2.boundingBox.height
            return y1 > y2
        }

        for observation in sorted {
            guard let text = observation.topCandidates(1).first?.string else { continue }
            let confidence = observation.topCandidates(1).first?.confidence ?? 0

            guard confidence > 0.3 else { continue }

            let (description, amount) = extractAmount(from: text)

            let lower = text.lowercased()
            if lower.contains("total") || lower.contains("合计") || lower.contains("小计") ||
               lower.contains("找零") || lower.contains("change") || lower.contains("谢谢") ||
               lower.contains("欢迎") || lower.contains("电话") || lower.contains("地址") {
                continue
            }

            let item = ReceiptItem(
                description: description.isEmpty ? text : description,
                amount: amount
            )
            items.append(item)
        }

        return items
    }

    private func extractAmount(from text: String) -> (description: String, amount: Double?) {
        let patterns = [
            "¥\\s*(\\d+\\.?\\d*)",
            "(\\d+\\.?\\d*)\\s*元",
            "(\\d+\\.\\d{1,2})\\s*$",
            "(\\d+)\\s*$"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

                if let amountRange = Range(match.range(at: 1), in: text) {
                    let amountStr = String(text[amountRange])
                    if let amount = Double(amountStr) {
                        var desc = text
                        if let fullRange = Range(match.range, in: text) {
                            desc = String(text[text.startIndex..<fullRange.lowerBound])
                                .trimmingCharacters(in: .whitespaces)
                            desc = desc.replacingOccurrences(of: "¥", with: "")
                                .trimmingCharacters(in: .whitespaces)
                        }
                        return (desc, amount)
                    }
                }
            }
        }

        return (text, nil)
    }
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无法处理这张图片"
        }
    }
}
