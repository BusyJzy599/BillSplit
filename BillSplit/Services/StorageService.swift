import Foundation
import Supabase

class StorageService {
    static let shared = StorageService()
    private let bucket = "avatars"

    func uploadAvatar(userId: String, image: UIImage) async throws -> String {
        guard let imageData = ImageCompressor.compressForAvatar(image) else {
            throw StorageError.compressFailed
        }

        let filePath = "\(userId)/avatar.jpg"
        try await supabase.storage
            .from(bucket)
            .upload(path: filePath, data: imageData, options: .init(upsert: true))

        return try supabase.storage
            .from(bucket)
            .getPublicURL(path: filePath)
            .absoluteString
    }

    func deleteAvatar(userId: String) async throws {
        let filePath = "\(userId)/avatar.jpg"
        try await supabase.storage
            .from(bucket)
            .remove(paths: [filePath])
    }
}

enum StorageError: LocalizedError {
    case compressFailed

    var errorDescription: String? {
        switch self {
        case .compressFailed: return "图片压缩失败"
        }
    }
}
