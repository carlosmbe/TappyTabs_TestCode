//
//  TestView.swift
//  TestTappyTabs
//
//  Created by Carlos Mbendera on 23/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import AVKit

struct TestView: View {
    @StateObject private var basicPitchEngine = BasicPitchEngine()
    @StateObject private var visionManager = VisionDetectionManager()
    
    @State private var isProcessing = false
    @State private var progressStatus = "Select a video to begin"
    @State private var generatedTab: String = ""
    @State private var showFileImporter = false
    @State private var tabVariations: [TabVariation] = []
    @State private var selectedVariationIndex = 0
    @State private var player: AVPlayer?
    @State private var videoURL: URL?
    @State private var visionHistoryData: [FretObservation] = []
    @State private var isPlaying = false
    @State private var currentDetections: [Detection] = []
    @State private var allFrameDetections: [(timestamp: TimeInterval, detections: [Detection])] = []
    @State private var updateTimer: Timer?
    @State private var showVideoPlayer = true
    
    private let tabGenerator = TabGeneratorEngine()
    
    var body: some View {
        GeometryReader { geometry in
            if player == nil {
                // Empty state - full screen
                emptyStateView
            } else {
                // Conditional layout based on showVideoPlayer toggle
                if showVideoPlayer {
                    // Split view - video on left, tabs on right
                    HSplitView {
                        // Left: Custom video player with bounding boxes
                        customVideoPlayerView
                            .frame(minWidth: 400)
                        
                        // Right: Tab results
                        tabResultsView
                            .frame(minWidth: 500)
                    }
                } else {
                    // Full-width tabs when video is hidden
                    tabResultsView
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType.movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                videoURL = url
                player = AVPlayer(url: url)
                setupPlayerObserver()
                processFile(url: url)
            case .failure(let error):
                print("File selection error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Image(systemName: "video.fill.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.3))
                
                VStack(spacing: 12) {
                    Text("Offline Video Tester")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Upload a guitar video to analyze")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Button(action: { showFileImporter = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "film")
                        Text("Select Video File")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Custom Video Player with Bounding Boxes
    
    private var customVideoPlayerView: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                if let player = player {
                    // Video layer
                    VideoPlayerRepresentable(player: player)
                    
                    // Bounding box overlay
                    BoundingBoxOverlay(
                        detections: currentDetections,
                        viewSize: geometry.size
                    )
                    
                    // Controls overlay
                    VStack {
                        Spacer()
                        
                        HStack {
                            // Status indicator
                            HStack(spacing: 8) {
                                if isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                
                                Text(progressStatus)
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.7))
                            )
                            
                            Spacer()
                            
                            // Play/Pause button
                            Button(action: {
                                if isPlaying {
                                    player.pause()
                                    isPlaying = false
                                } else {
                                    player.play()
                                    isPlaying = true
                                }
                            }) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.3))
                                    )
                            }
                            .buttonStyle(.plain)
                            
                            // New Video button
                            Button(action: {
                                updateTimer?.invalidate()
                                showFileImporter = true
                                player.pause()
                                isPlaying = false
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("New Video")
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.8))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                    }
                }
            }
        }
    }
    
    // MARK: - Tab Results View
    
    private var tabResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with hide/show video toggle
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Generated Tab")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if !basicPitchEngine.detectedNoteEvents.isEmpty {
                            Text("\(basicPitchEngine.detectedNoteEvents.count) notes detected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else if isProcessing {
                            Text("Processing...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Waiting for analysis...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Toggle video button
                    if player != nil {
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                showVideoPlayer.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: showVideoPlayer ? "eye.slash.fill" : "eye.fill")
                                Text(showVideoPlayer ? "Hide Video" : "Show Video")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.8))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                if !generatedTab.isEmpty {
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // Variation picker (if multiple variations exist)
                    if tabVariations.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Found \(tabVariations.count) playable variations:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Picker("", selection: $selectedVariationIndex) {
                                    ForEach(0..<tabVariations.count, id: \.self) { index in
                                        Text(tabVariations[index].name)
                                            .tag(index)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: selectedVariationIndex) { _, newIndex in
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
                }
                
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
    
    // MARK: - Helper Functions
    
    private func fretsUsed(in variation: TabVariation) -> String {
        let frets = Set(variation.notes.map { $0.fret }).sorted()
        return frets.map(String.init).joined(separator: ", ")
    }
    
    private func stringsUsed(in variation: TabVariation) -> String {
        let strings = Set(variation.notes.map { $0.string }).sorted()
        let stringNames = ["E", "A", "D", "G", "B", "e"]
        return strings.map { stringNames[$0] }.joined(separator: ", ")
    }
    
    private func setupPlayerObserver() {
        // Setup timer to update bounding boxes as video plays
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = player else { return }
            let currentTime = player.currentTime().seconds
            
            // Find detections for current timestamp
            let matchingFrame = allFrameDetections.first { frame in
                abs(frame.timestamp - currentTime) < 0.15 // 150ms tolerance
            }
            
            if let frame = matchingFrame {
                currentDetections = frame.detections
            } else {
                currentDetections = []
            }
        }
    }
    
    private func processFile(url: URL) {
        isProcessing = true
        progressStatus = "Reading file..."
        generatedTab = ""
        tabVariations = []
        selectedVariationIndex = 0
        visionHistoryData = []
        allFrameDetections = []
        currentDetections = []
        
        Task {
            do {
                // 1. Process Video (Vision) with frame-by-frame detections
                await MainActor.run {
                    progressStatus = "Analyzing video..."
                }
                let (visionHistory, frameDetections) = try await visionManager.processVideoFileWithDetections(url: url)
                
                await MainActor.run {
                    visionHistoryData = visionHistory
                    allFrameDetections = frameDetections
                    progressStatus = "Detected \(visionHistory.count) frames"
                    print("📦 Stored \(frameDetections.count) frames of detection data for visualization")
                }
                
                // 2. Process Audio (BasicPitch)
                await MainActor.run {
                    progressStatus = "Detecting notes..."
                }
                let audioEvents = await basicPitchEngine.analyzeAudio(audioURL: url)
                
                await MainActor.run {
                    progressStatus = "Found \(audioEvents.count) notes"
                }
                
                // Small delay to see the progress
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // 3. Generate Multiple Tab Variations! 🎸
                await MainActor.run {
                    progressStatus = "Generating tabs..."
                }
                
                let variations = tabGenerator.generateTabVariations(
                    audioNotes: audioEvents,
                    visionHistory: visionHistory
                )
                
                await MainActor.run {
                    if !variations.isEmpty {
                        tabVariations = variations
                        selectedVariationIndex = 0
                        generatedTab = tabGenerator.generateASCIITab(tabNotes: variations[0].notes)
                        progressStatus = "✓ \(variations.count) variations ready"
                    } else {
                        // Fallback to single tab if no variations
                        let tabNotes = tabGenerator.mapEventsToTab(
                            audioNotes: audioEvents,
                            visionHistory: visionHistory
                        )
                        generatedTab = tabGenerator.generateASCIITab(tabNotes: tabNotes)
                        progressStatus = "✓ Tab ready"
                    }
                    
                    isProcessing = false
                    
                    // Start playing video
                    player?.play()
                    isPlaying = true
                }
                
            } catch {
                await MainActor.run {
                    generatedTab = "Error: \(error.localizedDescription)"
                    isProcessing = false
                    progressStatus = "Error occurred"
                }
            }
        }
    }
}

// MARK: - Video Player Representable (No Auto-Loop)

struct VideoPlayerRepresentable: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer = playerLayer
        view.wantsLayer = true
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerLayer = nsView.layer as? AVPlayerLayer {
            playerLayer.frame = nsView.bounds
        }
    }
}

// MARK: - Bounding Box Overlay

struct BoundingBoxOverlay: View {
    let detections: [Detection]
    let viewSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(detections) { detection in
                    let rect = CGRect(
                        x: detection.boundingBox.origin.x * geometry.size.width,
                        y: (1 - detection.boundingBox.origin.y - detection.boundingBox.height) * geometry.size.height,
                        width: detection.boundingBox.width * geometry.size.width,
                        height: detection.boundingBox.height * geometry.size.height
                    )
                    
                    ZStack {
                        // Bounding box
                        Rectangle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                        
                        // Label with fret number
                        Text(detection.label)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(6)
                            .position(x: rect.minX + 30, y: rect.minY + 15)
                    }
                }
            }
        }
    }
}

#Preview {
    TestView()
}
