//
//  ImageStore.swift
//  MuseumMate
//
//  Disk persistence for scanned images. Saves a full-size JPEG plus a
//  300×300 thumbnail into the Documents directory under UUID filenames.
//  ScanResult stores only the filenames.
//

import UIKit

enum ImageStore {
    private static let thumbnailSide: CGFloat = 300

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func url(for fileName: String) -> URL {
        documentsURL.appendingPathComponent(fileName)
    }

    // MARK: - Save

    /// Saves a full-size image. Returns the generated filename, or nil on failure.
    @discardableResult
    static func saveImage(_ image: UIImage, quality: CGFloat = 0.85) -> String? {
        let fileName = "\(UUID().uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        do {
            try data.write(to: url(for: fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    /// Saves a 300×300 thumbnail. Returns the generated filename, or nil on failure.
    @discardableResult
    static func saveThumbnail(_ image: UIImage, quality: CGFloat = 0.7) -> String? {
        let thumb = downscaled(image, to: thumbnailSide)
        let fileName = "thumb_\(UUID().uuidString).jpg"
        guard let data = thumb.jpegData(compressionQuality: quality) else { return nil }
        do {
            try data.write(to: url(for: fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    /// Saves both full image and thumbnail in one call.
    static func save(_ image: UIImage) -> (image: String?, thumbnail: String?) {
        (saveImage(image), saveThumbnail(image))
    }

    // MARK: - Load

    static func loadImage(named fileName: String?) -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        return UIImage(contentsOfFile: url(for: fileName).path)
    }

    // MARK: - Delete

    static func deleteImage(named fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// Removes both the full image and thumbnail for a scan result.
    static func delete(_ result: ScanResult) {
        deleteImage(named: result.imageFileName)
        deleteImage(named: result.thumbnailFileName)
    }

    // MARK: - Helpers

    /// Aspect-fill downscale so the shorter side is `side`, then center-crop to square.
    private static func downscaled(_ image: UIImage, to side: CGFloat) -> UIImage {
        let scale = max(side / image.size.width, side / image.size.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (side - scaledSize.width) / 2, y: (side - scaledSize.height) / 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}
