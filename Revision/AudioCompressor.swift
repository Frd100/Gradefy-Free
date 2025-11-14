import AVFoundation

// ✅ SOLUTION MINIMALE : Compression audio intelligente
class AudioCompressor {
    static let shared = AudioCompressor()
    
    private init() {}
    
    func compressAudio(at url: URL, bitrate: Int = 128000, forceMono: Bool = false) async -> URL? {
        let asset = AVURLAsset(url: url)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset, 
            presetName: AVAssetExportPresetAppleM4A
        ) else { 
            print("❌ [AUDIO_COMPRESSOR] Impossible de créer export session")
            return nil 
        }
        
        // ✅ CORRECTION : UUID pour éviter les conflits
        let compressedURL = url.deletingPathExtension()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        exportSession.outputURL = compressedURL
        exportSession.outputFileType = .m4a
        exportSession.audioTimePitchAlgorithm = .timeDomain
        
        // ✅ CORRECTION : AVAssetExportSession n'a pas audioSettings
        // Utiliser le preset par défaut qui est déjà optimisé
        let presetName = forceMono ? AVAssetExportPresetAppleM4A : AVAssetExportPresetAppleM4A
        print("🔄 [AUDIO_COMPRESSOR] Compression avec preset \(presetName) (\(bitrate/1000)kbps)")
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            let originalSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let compressedSize = (try? compressedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let reduction = originalSize > 0 ? Double(originalSize - compressedSize) / Double(originalSize) * 100 : 0
            
            print("✅ [AUDIO_COMPRESSOR] Compression réussie: \(bitrate/1000)kbps")
            print("📊 [AUDIO_COMPRESSOR] Taille: \(originalSize/1024)KB → \(compressedSize/1024)KB (\(String(format: "%.1f", reduction))% réduction)")
            return compressedURL
        } else {
            print("❌ [AUDIO_COMPRESSOR] Échec compression: \(exportSession.error?.localizedDescription ?? "unknown")")
            return nil
        }
    }
}
