import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// 灵感图片的文件存储：原图 + 缩略图，位于 Application Support/MemoImages
struct ImageStore {
    let directory: URL
    private let thumbCache = NSCache<NSString, UIImage>()

    enum ImageStoreError: LocalizedError {
        case unsupportedImage

        var errorDescription: String? { "图片格式无法识别" }
    }

    struct StoredImage {
        let filename: String
        let thumbFilename: String
    }

    static let shared: ImageStore = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("MemoImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return ImageStore(directory: dir)
    }()

    // MARK: - 写入

    /// 将原始图片数据降采样为 JPEG 原图（≤2048px）+ 缩略图（≤320px）并写入磁盘
    func write(data: Data) throws -> StoredImage {
        guard let full = Self.jpegData(from: data, maxSide: 2048) else {
            throw ImageStoreError.unsupportedImage
        }
        let thumb = Self.jpegData(from: data, maxSide: 320) ?? full
        let base = UUID().uuidString
        let filename = "\(base).jpg"
        let thumbFilename = "\(base)_t.jpg"
        try full.write(to: url(for: filename), options: .atomic)
        try thumb.write(to: url(for: thumbFilename), options: .atomic)
        return StoredImage(filename: filename, thumbFilename: thumbFilename)
    }

    func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    // MARK: - 读取

    func thumbnail(for asset: ImageAsset) -> UIImage? {
        let key = asset.thumbFilename as NSString
        if let cached = thumbCache.object(forKey: key) { return cached }
        let image = UIImage(contentsOfFile: url(for: asset.thumbFilename).path)
        if let image { thumbCache.setObject(image, forKey: key) }
        return image
    }

    func fullImage(for asset: ImageAsset) -> UIImage? {
        UIImage(contentsOfFile: url(for: asset.filename).path)
    }

    // MARK: - 删除

    func delete(filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
        thumbCache.removeObject(forKey: filename as NSString)
    }

    func delete(asset: ImageAsset) {
        delete(filename: asset.filename)
        delete(filename: asset.thumbFilename)
    }

    // MARK: - 降采样

    /// ImageIO 降采样并输出 JPEG（自动纠正方向，HEIC/PNG 等统一转 JPEG）
    static func jpegData(from data: Data, maxSide: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let quality: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.85]
        CGImageDestinationAddImage(destination, cgImage, quality as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
