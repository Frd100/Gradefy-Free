import AVFoundation

let session = AVAudioSession.sharedInstance()
print("Audio session category: \(session.category)")
print("Available inputs: \(session.availableInputs?.count ?? 0)")

let status = AVCaptureDevice.authorizationStatus(for: .audio)
print("Authorization status: \(status.rawValue)")
// 0 = notDetermined, 1 = restricted, 2 = denied, 3 = authorized
