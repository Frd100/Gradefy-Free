import ImageIO
import UIKit

// ✅ SOLUTION SIMPLIFIÉE : Compression adaptée aux limites Gradefy
class ImageCompressor {
    static let shared = ImageCompressor()

    enum ImageUsage {
        case flashcard // 1200px max
        case thumbnail // 150px max

        var maxDimension: CGFloat {
            switch self {
            case .flashcard: return 1200
            case .thumbnail: return 150
            }
        }

        var maxFileSize: Int {
            switch self {
            case .flashcard: return 500_000 // 500KB
            case .thumbnail: return 50000 // 50KB
            }
        }
    }

    // ✅ CORRECTION : Downsample I/O avec EXIF
    func downsampledImage(from url: URL, maxDimension: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }

        let maxPx = Int(maxDimension * UIScreen.main.scale)
        let thumbOpts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPx,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ] as CFDictionary

        guard let cgimg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts) else { return nil }
        return UIImage(cgImage: cgimg)
    }

    // ✅ CORRECTION : Compression stricte avec respect du maxFileSize
    func compressImage(_ image: UIImage, for usage: ImageUsage) -> Data? {
        // Redimensionner avec respect du ratio
        let resizedImage = resizeImage(image, maxDimension: usage.maxDimension)

        // Essayer PNG d'abord (garde alpha)
        if let pngData = resizedImage.pngData(), pngData.count <= usage.maxFileSize {
            return pngData
        }

        // Fallback JPEG avec qualité adaptée
        let qualities: [CGFloat] = [0.8, 0.6, 0.4]
        for quality in qualities {
            if let jpegData = resizedImage.jpegData(compressionQuality: quality),
               jpegData.count <= usage.maxFileSize
            {
                return jpegData
            }
        }

        // ✅ CORRECTION : Recherche dichotomique pour respecter strictement maxFileSize
        return compressToTargetSize(resizedImage, targetSize: usage.maxFileSize)
    }

    // ✅ NOUVELLE MÉTHODE : Compression progressive avec respect strict des limites
    private func compressToTargetSize(_ image: UIImage, targetSize: Int) -> Data? {
        var compression: CGFloat = 0.9
        var data: Data?

        // Recherche dichotomique pour la compression optimale
        var minCompression: CGFloat = 0.0
        var maxCompression: CGFloat = 1.0

        for _ in 0 ..< 10 { // Maximum 10 itérations
            compression = (minCompression + maxCompression) / 2.0
            data = image.jpegData(compressionQuality: compression)

            guard let data = data else { break }

            if data.count <= targetSize {
                minCompression = compression
            } else {
                maxCompression = compression
            }

            // Si on a trouvé une taille acceptable, on s'arrête
            if abs(data.count - targetSize) < Int(Double(targetSize) * 0.05) { // 5% de tolérance
                break
            }
        }

        // ✅ VÉRIFICATION FINALE : Si toujours trop gros, on refuse
        if let finalData = data, finalData.count <= targetSize {
            return finalData
        } else {
            print("❌ [IMAGE_COMPRESSOR] Impossible de compresser l'image à \(targetSize) bytes")
            return nil
        }
    }

    // ✅ CORRECTION : Respect du ratio d'aspect
    func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = image.size.width, h = image.size.height
        let scale = min(maxDimension / max(w, h), 1) // Pas d'upscale
        let newSize = CGSize(width: floor(w * scale), height: floor(h * scale))

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
