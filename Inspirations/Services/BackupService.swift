import CryptoKit
import Foundation
import SwiftData

// MARK: - 导出 Schema（version 1，冻结）

struct ExportedImage: Codable {
    let id: UUID
    let data: String
}

struct ExportedMemo: Codable {
    let id: UUID
    let content: String
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let images: [ExportedImage]
}

struct BackupDocument: Codable {
    let app: String
    let version: Int
    let exportedAt: Date
    let memoCount: Int
    let memos: [ExportedMemo]
}

struct ImportResult {
    var inserted = 0
    var skipped = 0
    var duplicated = 0
}

enum BackupError: LocalizedError {
    case unsupportedVersion
    case malformed
    case readFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "备份文件版本不受支持"
        case .malformed: return "备份文件格式有误"
        case .readFailed: return "无法读取备份文件"
        }
    }
}

/// 备份导出/导入（在主线程执行，因其访问 MemoStore 与模型上下文）
@MainActor
enum BackupService {
    static let currentVersion = 1

    // MARK: - 导出

    static func exportJSON(store: MemoStore) throws -> URL {
        let memos = store.allMemos()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let name = "灵感备份-\(formatter.string(from: .now)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)

        let document = BackupDocument(
            app: "inspirations",
            version: currentVersion,
            exportedAt: .now,
            memoCount: memos.count,
            memos: memos.map { memo in
                ExportedMemo(
                    id: memo.id,
                    content: memo.content,
                    tags: memo.tags.map(\.path).sorted(),
                    createdAt: memo.createdAt,
                    updatedAt: memo.updatedAt,
                    images: memo.sortedImages.compactMap { asset in
                        guard let data = try? Data(contentsOf: store.imageStore.url(for: asset.filename)) else {
                            return nil
                        }
                        return ExportedImage(id: asset.id, data: data.base64EncodedString())
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - 导入

    enum Mode {
        case merge
        case replace
    }

    static func importJSON(from url: URL, mode: Mode, store: MemoStore) throws -> ImportResult {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let raw: Data
        do {
            raw = try Data(contentsOf: url)
        } catch {
            throw BackupError.readFailed
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: BackupDocument
        do {
            document = try decoder.decode(BackupDocument.self, from: raw)
        } catch {
            throw BackupError.malformed
        }
        guard document.version == currentVersion else {
            throw BackupError.unsupportedVersion
        }

        if mode == .replace {
            store.deleteAll()
        }

        let existingMemos = store.allMemos()
        let existingByID = Dictionary(uniqueKeysWithValues: existingMemos.map { ($0.id, $0) })
        var result = ImportResult()

        for exported in document.memos {
            let targetID: UUID
            let isDuplicateCopy: Bool
            if let existing = existingByID[exported.id] {
                if existing.content.sha256Hex == exported.content.sha256Hex {
                    result.skipped += 1
                    continue
                }
                // 内容不同 → 以新 UUID 复制，不覆盖本地修改
                targetID = UUID()
                isDuplicateCopy = true
            } else {
                targetID = exported.id
                isDuplicateCopy = false
            }

            let memo = Memo(
                id: targetID,
                content: exported.content,
                createdAt: exported.createdAt,
                updatedAt: exported.updatedAt
            )
            let images = exported.images.compactMap { image -> (id: UUID, data: Data)? in
                guard let data = Data(base64Encoded: image.data) else { return nil }
                return (image.id, data)
            }
            store.insertImported(memo, images: images, tagPaths: exported.tags)
            if isDuplicateCopy {
                result.duplicated += 1
            } else {
                result.inserted += 1
            }
        }
        store.save()
        return result
    }
}
