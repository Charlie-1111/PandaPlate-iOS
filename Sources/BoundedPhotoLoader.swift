import Foundation
import ImageIO
import UniformTypeIdentifiers

struct BoundedPhotoLoader {
    static let maximumInputBytes = 12_000_000
    static let maximumPixelDimension = 1_200

    static func mayPublishResult(requestID: UUID, activeID: UUID, isCancelled: Bool) -> Bool {
        !isCancelled && requestID == activeID
    }

    static func jpegData(from data: Data) -> Data? {
        guard data.count <= maximumInputBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.65] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
