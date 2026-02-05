//
//  AudioRecordingManager.swift
//  TestTappyTabs
//
//  Created by Carlos Mbendera on 23/11/2025.
//

import AVFoundation
import Combine

class AudioRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var errorMessage: String?
    
    private var audioRecorder: AVAudioRecorder?
    
    override init() {
        super.init()
    }
    
    func startRecording() {
        // Create a unique filename for this recording
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingURL = fileURL
            }
            
            print("✅ Audio recording started: \(fileURL.path)")
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start recording: \(error.localizedDescription)"
            }
            print("Recording error: \(error)")
        }
    }
    
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return nil
        }
        
        recorder.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        print("✅ Audio recording stopped: \(String(describing: recordingURL?.path))")
        return recordingURL
    }
    
    deinit {
        if audioRecorder?.isRecording == true {
            audioRecorder?.stop()
        }
    }
}
