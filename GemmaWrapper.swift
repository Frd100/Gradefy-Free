import Foundation
import CoreML

@available(iOS 17.0, *)
class GemmaOllamaWrapper {
    private let modelPath: String
    
    init() {
        self.modelPath = "gemma2:2b"
    }
    
    func generateText(prompt: String, completion: @escaping (String) -> Void) {
        // Version qui utilise vraiment Ollama
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/env"
            task.arguments = ["bash", "-c", "echo '\(prompt.replacingOccurrences(of: "'", with: "\\'"))' | ollama run gemma2:2b"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let result = String(data: data, encoding: .utf8) ?? "Erreur de génération"
                
                DispatchQueue.main.async {
                    completion(result.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            } catch {
                DispatchQueue.main.async {
                    completion("Erreur: \(error.localizedDescription)")
                }
            }
        }
    }
}
