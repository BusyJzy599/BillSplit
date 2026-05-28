import UIKit

enum ImageCompressor {
    static func compressForAvatar(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 512
        let size = image.size
        let scale: CGFloat
        if size.width > size.height {
            scale = min(maxDimension / size.width, 1.0)
        } else {
            scale = min(maxDimension / size.height, 1.0)
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resized.jpegData(compressionQuality: 0.7)
    }
}
