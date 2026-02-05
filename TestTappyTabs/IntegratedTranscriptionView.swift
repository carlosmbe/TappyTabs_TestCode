//
//  IntegratedTranscriptionView.swift
//  TestTappyTabs
//
//  Created by Carlos Mbendera on 23/11/2025.
//

import SwiftUI
import AVFoundation


struct IntegratedTranscriptionView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var visionManager = VisionDetectionManager()
    @StateObject private var audioManager = AudioRecordingManager()
    @StateObject private var basicPitchEngine = BasicPitchEngine()
    
    @State private var isRecording = false
    @State private var showProcessing = false
    @State private var generatedTab: String = ""
    @State private var showTabResult = false
    @State private var recordingStartTime: Date?
    @State private var tabVariations: [TabVariation] = []
    @State private var selectedVariationIndex = 0
    
    @Environment(\.dismiss) var dismiss
    
    var recordingDuration: String {
        guard let startTime = recordingStartTime else { return "0:00" }
        let duration = Int(Date().timeIntervalSince(startTime))
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private let tabGenerator = TabGeneratorEngine()
    
    var body: some View {
        ZStack {
            if !showTabResult {
                cameraRecordingView
            } else {
                tabResultView
            }
            
            if showProcessing {
                processingOverlay
            }
        }
        .navigationBarBackButtonHidden(isRecording)
    }
    
    // MARK: - Camera Recording View
    
    private var cameraRecordingView: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                if cameraManager.permissionGranted && cameraManager.sessionRunning {
                    CameraPreviewView(session: cameraManager.session)
                    
                    DetectionOverlayView(
                        detections: visionManager.detections,
                        viewSize: geometry.size
                    )
                } else {
                    permissionPrompt
                }
                
                // UI overlay
                VStack(spacing: 0) {
                    statusBar
                    Spacer()
                    controlsArea
                }
            }
            .onAppear {
                setupSession()
            }
            .onDisappear {
                cleanup()
            }
        }
        .background(Color.black)
    }
    
    // MARK: - UI Components
    
    private var permissionPrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Camera Access Needed")
                    .font(.title)
                    .foregroundColor(.white)
                
                Text("Point your camera at the guitar fretboard")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            if !cameraManager.permissionGranted {
                Button(action: {
                    cameraManager.requestPermission()
                }) {
                    Text("Grant Access")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: 400)
        .padding(40)
    }
    
    private var statusBar: some View {
        HStack(alignment: .top, spacing: 16) {
            // Status info
            VStack(alignment: .leading, spacing: 8) {
                // Recording status
                HStack(spacing: 8) {
                    Circle()
                        .fill(isRecording ? Color.red : Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(isRecording ? Color.red.opacity(0.3) : Color.clear, lineWidth: 3)
                                .scaleEffect(1.5)
                        )
                    
                    Text(isRecording ? "Recording \(recordingDuration)" : "Ready")
                        .font(.headline)
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                
                // Detection info
                if visionManager.modelLoaded {
                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder")
                            .font(.caption)
                        Text("\(visionManager.detections.count) detection\(visionManager.detections.count == 1 ? "" : "s")")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                
                // Active frets
                if !visionManager.detectedFretZones.isEmpty && isRecording {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.caption2)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(visionManager.detectedFretZones.prefix(8), id: \.self) { fret in
                                    Text("\(fret)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.8))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .frame(maxWidth: 120)
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.75))
                    .shadow(color: .black.opacity(0.3), radius: 8)
            )
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var controlsArea: some View {
        VStack(spacing: 24) {
            // Recording instructions
            if isRecording {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title3)
                        Text("Play your guitar")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    
                    Text("Tap Stop when you're done")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.75))
                        .shadow(color: .black.opacity(0.3), radius: 8)
                )
            } else {
                VStack(spacing: 6) {
                    Text("Tap Record to start")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    Text("Position camera to see fretboard")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Main record button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    toggleRecording()
                }
            }) {
                VStack(spacing: 14) {
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 90, height: 90)
                        
                        // Inner button
                        if isRecording {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red)
                                .frame(width: 36, height: 36)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 72, height: 72)
                        }
                    }
                    .shadow(color: isRecording ? .red.opacity(0.5) : .clear, radius: 20)
                    
                    Text(isRecording ? "Stop & Generate" : "Record")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(showProcessing)
        }
        .padding(.bottom, 60)
    }
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.8)
                    .tint(.white)
                
                VStack(spacing: 12) {
                    Text("Generating Tab")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(basicPitchEngine.stateMessage)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .padding(50)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
                    .shadow(radius: 30)
            )
        }
    }
    
    // MARK: - Tab Result View
    
    private var tabResultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Tab")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if !basicPitchEngine.detectedNoteEvents.isEmpty {
                            Text("\(basicPitchEngine.detectedNoteEvents.count) notes detected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showTabResult = false
                        generatedTab = ""
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("New Recording")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Divider()
                    .padding(.horizontal, 24)
                
                // Variation picker (if multiple variations exist)
                if tabVariations.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Found \(tabVariations.count) playable variations:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $selectedVariationIndex) {
                                ForEach(0..<tabVariations.count, id: \.self) { index in
                                    Text(tabVariations[index].name)
                                        .tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedVariationIndex) { newIndex in
                                generatedTab = tabGenerator.generateASCIITab(tabNotes: tabVariations[newIndex].notes)
                            }
                        }
                        
                        // Quick stats for selected variation
                        if selectedVariationIndex < tabVariations.count {
                            let variation = tabVariations[selectedVariationIndex]
                            HStack(spacing: 20) {
                                HStack(spacing: 6) {
                                    Image(systemName: "music.note")
                                        .font(.caption)
                                    Text("\(variation.notes.count) notes")
                                        .font(.caption)
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "number")
                                        .font(.caption)
                                    Text("Frets: \(fretsUsed(in: variation))")
                                        .font(.caption)
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.caption)
                                    Text("Strings: \(stringsUsed(in: variation))")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.08))
                    )
                    .padding(.horizontal, 24)
                }
                
                // Tab notation
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "music.note.list")
                            .font(.title3)
                            .foregroundColor(.blue)
                        if tabVariations.count > 1 && selectedVariationIndex < tabVariations.count {
                            Text("Guitar Tab (\(tabVariations[selectedVariationIndex].name))")
                                .font(.headline)
                        } else {
                            Text("Guitar Tab")
                                .font(.headline)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(generatedTab)
                            .font(.system(.body, design: .monospaced))
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                            .padding(.horizontal, 24)
                    }
                }
                
                // Detected notes
                if !basicPitchEngine.detectedNoteEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "music.note")
                                .font(.title3)
                                .foregroundColor(.blue)
                            Text("Detected Notes")
                                .font(.headline)
                        }
                        .padding(.horizontal, 24)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(basicPitchEngine.detectedNoteEvents) { event in
                                    Text(event.noteName)
                                        .font(.system(.callout, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(Color.blue.opacity(0.8))
                                        )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text("How to Read")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        instructionRow(icon: "line.3.horizontal", text: "Each line = one guitar string (e=high E, E=low E)")
                        instructionRow(icon: "number", text: "Numbers = fret positions to press")
                        instructionRow(icon: "circle", text: "0 = play open string (no fret)")
                        instructionRow(icon: "arrow.right", text: "Read from left to right")
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.08))
                )
                .padding(.horizontal, 24)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue.opacity(0.8))
                .frame(width: 20)
            
            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func setupSession() {
        cameraManager.checkPermission()
        if cameraManager.permissionGranted {
            cameraManager.setupSession()
            cameraManager.videoOutputDelegate = visionManager
            cameraManager.startSession()
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecordingAndProcess()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordingStartTime = Date()
        visionManager.startRecordingSession()
        audioManager.startRecording()
        print("🎬 Started recording session")
    }
    
    private func stopRecordingAndProcess() {
        isRecording = false
        recordingStartTime = nil
        
        guard let audioURL = audioManager.stopRecording() else {
            print("❌ Failed to get audio recording")
            return
        }
        
        // Get the full history now
        let visionHistory = visionManager.stopRecordingSession()
        
        print("🎵 Processing audio: \(audioURL.path)")
        print("👁 Vision history frames: \(visionHistory.count)")
        
        showProcessing = true
        
        Task {
            await processAudioAndGenerateTab(audioURL: audioURL, visionHistory: visionHistory)
        }
    }
    
    private func processAudioAndGenerateTab(audioURL: URL, visionHistory: [FretObservation]) async {
        // Call async function directly - no more race condition loop!
        let audioEvents = await basicPitchEngine.analyzeAudio(audioURL: audioURL)
        
        await MainActor.run {
            print("🎵 Audio Events: \(audioEvents.count)")
            print("👁 Vision Frames: \(visionHistory.count)")
            
            // Generate multiple tab variations
            let variations = tabGenerator.generateTabVariations(
                audioNotes: audioEvents,
                visionHistory: visionHistory
            )
            
            if !variations.isEmpty {
                tabVariations = variations
                selectedVariationIndex = 0
                generatedTab = tabGenerator.generateASCIITab(tabNotes: variations[0].notes)
                print("✅ Generated \(variations.count) tab variations")
            } else {
                // Fallback to single tab if variations fail
                let tabNotes = tabGenerator.mapEventsToTab(
                    audioNotes: audioEvents,
                    visionHistory: visionHistory
                )
                generatedTab = tabGenerator.generateASCIITab(tabNotes: tabNotes)
                print("⚠️ Using fallback tab generation")
            }
            
            print("✅ Tab generation complete.")
            
            showProcessing = false
            showTabResult = true
        }
    }
    
    private func cleanup() {
        if isRecording {
            _ = audioManager.stopRecording()
            _ = visionManager.stopRecordingSession()
        }
        cameraManager.stopSession()
    }
    
    private func fretsUsed(in variation: TabVariation) -> String {
        let frets = Set(variation.notes.map { $0.fret }).sorted()
        return frets.map(String.init).joined(separator: ", ")
    }
    
    private func stringsUsed(in variation: TabVariation) -> String {
        let stringNames = ["E", "A", "D", "G", "B", "e"]
        let strings = Set(variation.notes.map { $0.string }).sorted()
        return strings.map { stringNames[$0] }.joined(separator: ", ")
    }
    
    private func noteNameToMIDI(_ noteName: String) -> Int? {
        let noteMap: [String: Int] = [
            "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
            "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
        ]
        
        let pattern = "^([A-G]#?)(-?\\d+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: noteName, range: NSRange(noteName.startIndex..., in: noteName)),
              let noteRange = Range(match.range(at: 1), in: noteName),
              let octaveRange = Range(match.range(at: 2), in: noteName) else {
            return nil
        }
        
        let note = String(noteName[noteRange])
        let octave = Int(noteName[octaveRange]) ?? 0
        
        guard let noteValue = noteMap[note] else {
            return nil
        }
        
        return (octave + 1) * 12 + noteValue
    }
}
