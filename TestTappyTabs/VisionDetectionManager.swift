//
//  VisionDetectionManager.swift
//  TestTappyTabs
//
//  Created by Carlos Mbendera on 21/11/2025.
//

import AVFoundation
import Vision
import CoreML
import Combine

struct Detection: Identifiable {
    let id = UUID()
    let boundingBox: CGRect
    let confidence: Float
    let label: String
}

struct FretObservation {
    let timestamp: TimeInterval
    let frets: [Int]
}

class VisionDetectionManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var detections: [Detection] = []
    @Published var errorMessage: String?
    @Published var detectedFretZones: [Int] = []
    @Published var modelLoaded: Bool = false
    
    private var visionModel: VNCoreMLModel?
    private let sequenceHandler = VNSequenceRequestHandler()
    
    // Session management
    private var isRecording = false
    private var recordingStartTime: Date?
    private var detectionHistory: [FretObservation] = []
    
    override init() {
        super.init()
        setupModel()
    }
    
    private func setupModel() {
        do {
            var modelURL: URL?
            modelURL = Bundle.main.url(forResource: "TapToTab_640_Speed", withExtension: "mlmodelc")
            
            if modelURL == nil {
                modelURL = Bundle.main.url(forResource: "TapToTab_640_Speed", withExtension: "mlpackage")
            }
            
            if modelURL == nil {
                let resourcePath = Bundle.main.resourcePath
                if let resourcePath = resourcePath {
                    let compiledPath = (resourcePath as NSString).appendingPathComponent("TapToTab_640_Speed.mlmodelc")
                    if FileManager.default.fileExists(atPath: compiledPath) {
                        modelURL = URL(fileURLWithPath: compiledPath)
                    }
                }
            }
            
            guard let modelURL = modelURL else {
                errorMessage = "Model file not found in bundle."
                return
            }
            
            let mlModel = try MLModel(contentsOf: modelURL)
            visionModel = try VNCoreMLModel(for: mlModel)
            
            DispatchQueue.main.async { self.modelLoaded = true }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load model: \(error.localizedDescription)"
                self.modelLoaded = false
            }
        }
    }
    
    // MARK: - Live Capture
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        performLiveDetection(on: pixelBuffer)
    }
    
    private func performLiveDetection(on pixelBuffer: CVPixelBuffer) {
        guard let model = visionModel else { return }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let self = self else { return }
            if error == nil {
                self.processLiveDetections(request.results)
            }
        }
        request.imageCropAndScaleOption = .scaleFill
        try? sequenceHandler.perform([request], on: pixelBuffer)
    }
    
    private func processLiveDetections(_ results: [Any]?) {
        guard let results = results else { return }
        var newDetections: [Detection] = []
        var currentFrameFrets: [Int] = []
        
        for result in results {
            if let observation = result as? VNRecognizedObjectObservation {
                let confidence = observation.labels.first?.confidence ?? observation.confidence
                let label = observation.labels.first?.identifier ?? "Unknown"
                
                if confidence > 0.3 {
                    newDetections.append(Detection(boundingBox: observation.boundingBox, confidence: confidence, label: label))
                    if let fret = extractFretNumber(from: label) {
                        currentFrameFrets.append(fret)
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.detections = newDetections
            self.detectedFretZones = Array(Set(currentFrameFrets)).sorted()
        }
        
        if isRecording, let startTime = recordingStartTime {
            let timestamp = Date().timeIntervalSince(startTime)
            let uniqueFrets = Array(Set(currentFrameFrets))
            if !uniqueFrets.isEmpty {
                detectionHistory.append(FretObservation(timestamp: timestamp, frets: uniqueFrets))
            }
        }
    }
    
    // MARK: - Offline File Processing
    func processVideoFile(url: URL) async throws -> [FretObservation] {
        guard let model = visionModel else {
            throw NSError(domain: "VisionDetection", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        let asset = AVAsset(url: url)
        let reader = try AVAssetReader(asset: asset)
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VisionDetection", code: 2, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(trackOutput)
        reader.startReading()
        
        var history: [FretObservation] = []
        let fileHandler = VNSequenceRequestHandler() // Use separate handler
        
        print("👁 Processing video frames...")
        
        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = .scaleFill
            
            // Synchronous call for file processing
            try? fileHandler.perform([request], on: pixelBuffer)
            
            if let results = request.results as? [VNRecognizedObjectObservation] {
                var frameFrets: [Int] = []
                for obs in results {
                    // Threshold check
                    if obs.confidence > 0.3,
                       let label = obs.labels.first?.identifier,
                       let fret = extractFretNumber(from: label) {
                        frameFrets.append(fret)
                    }
                }
                
                let unique = Array(Set(frameFrets)).sorted()
                if !unique.isEmpty {
                    history.append(FretObservation(timestamp: timestamp, frets: unique))
                }
            }
        }
        
        print("👁 Finished processing. Found \(history.count) frames with detections.")
        return history
    }
    
    // Process video file and return both history and frame-by-frame detections for visualization
    func processVideoFileWithDetections(url: URL) async throws -> ([FretObservation], [(timestamp: TimeInterval, detections: [Detection])]) {
        guard let model = visionModel else {
            throw NSError(domain: "VisionDetection", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        let asset = AVAsset(url: url)
        let reader = try AVAssetReader(asset: asset)
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VisionDetection", code: 2, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(trackOutput)
        reader.startReading()
        
        var history: [FretObservation] = []
        var frameDetections: [(timestamp: TimeInterval, detections: [Detection])] = []
        let fileHandler = VNSequenceRequestHandler()
        
        print("👁 Processing video frames with full detection data...")
        
        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = .scaleFill
            
            try? fileHandler.perform([request], on: pixelBuffer)
            
            if let results = request.results as? [VNRecognizedObjectObservation] {
                var frameFrets: [Int] = []
                var frameDetectionObjects: [Detection] = []
                
                for obs in results {
                    if obs.confidence > 0.3,
                       let label = obs.labels.first?.identifier,
                       let fret = extractFretNumber(from: label) {
                        frameFrets.append(fret)
                        
                        // Create Detection object for visualization
                        let detection = Detection(
                            boundingBox: obs.boundingBox,
                            confidence: obs.confidence,
                            label: label
                        )
                        frameDetectionObjects.append(detection)
                    }
                }
                
                let unique = Array(Set(frameFrets)).sorted()
                if !unique.isEmpty {
                    history.append(FretObservation(timestamp: timestamp, frets: unique))
                    frameDetections.append((timestamp: timestamp, detections: frameDetectionObjects))
                }
            }
        }
        
        print("👁 Finished processing. Found \(history.count) frames with detections.")
        return (history, frameDetections)
    }
    
    private func extractFretNumber(from label: String) -> Int? {
        let pattern = "(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)),
              let range = Range(match.range(at: 1), in: label) else {
            return nil
        }
        return Int(label[range])
    }
    
    func startRecordingSession() {
        recordingStartTime = Date()
        detectionHistory.removeAll()
        isRecording = true
    }
    
    func stopRecordingSession() -> [FretObservation] {
        isRecording = false
        recordingStartTime = nil
        return detectionHistory
    }
}
