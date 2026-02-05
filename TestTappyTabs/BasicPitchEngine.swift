//
//  BasicPitchEngine.swift
//  TestTappyTabs
//
//  Created by Carlos Mbendera on 21/11/2025.
//

import Combine
import SwiftUI
import BasicPitch
import AVFoundation
internal import MIDIKitSMF

struct NoteEvent: Identifiable, Equatable {
    let id = UUID()
    let noteName: String
    let midiNumber: Int
    let startTime: TimeInterval
    let duration: TimeInterval
}

class BasicPitchEngine: ObservableObject {
    @Published var stateMessage: String = "Ready to Import"
    @Published var isProcessing: Bool = false
    @Published var detectedNoteEvents: [NoteEvent] = []
    
    private let confidenceThreshold: UInt7 = 60
    
    private func processAudio(_ audioFile: URL) async -> NotesConverter? {
        return await Task.detached {
            do {
                return try await BasicPitch.predict(audioFile)
            } catch {
                print("Prediction failed: \(error)")
                return nil
            }
        }.value
    }
    
    // MARK: - Async Analysis
    @MainActor
    func analyzeAudio(audioURL: URL) async -> [NoteEvent] {
        self.isProcessing = true
        self.stateMessage = "Analyzing..."
        self.detectedNoteEvents = []
        
        // 1. Run Basic Pitch Inference
        guard let converter = await processAudio(audioURL) else {
            self.stateMessage = "Analysis failed."
            self.isProcessing = false
            return []
        }
        
        // 2. Convert to Internal Notes
        // The error suggests 'convert' is isolated. If 'converter' is an actor, we must await.
        // We try await if it's an async actor method, or just await if it's on an actor.
        // Assuming NotesConverter is an actor based on the error.
        let internalNotes: [Note]
        do {
            // Try await if it allows, otherwise we might need to hop to a detached task
            // but usually, this means simply:
            internalNotes = await try! converter.convert()
        }
        
        if internalNotes.isEmpty {
            self.stateMessage = "No notes detected."
            self.isProcessing = false
            return []
        }
        
        // 3. Write to MIDI to extract timing data
        // MidiWriter might also be an actor.
        let writer = MidiWriter(notes: internalNotes)
        let midiFile: MIDIFile
        
        // Try awaiting write
        midiFile = await writer.write()
        
        // 4. Extract Notes with Timing
        // This part is our own non-actor code, so it runs synchronously here.
        let events = extractNoteEventsFromMIDI(file: midiFile)
        
        self.detectedNoteEvents = events
        self.stateMessage = "Found \(events.count) notes."
        self.isProcessing = false
        
        return events
    }
    
    // Helper must be non-isolated or MainActor since it's called from MainActor
    private func extractNoteEventsFromMIDI(file: MIDIFile) -> [NoteEvent] {
        var noteEvents: [NoteEvent] = []
        let ticksPerBeat: Double = 960.0
        var currentTempoBPM: Double = 120.0
        
        for chunk in file.chunks {
            guard case .track(let track) = chunk else { continue }
            
            var currentTime: TimeInterval = 0.0
            var activeNotes: [Int: (TimeInterval, UInt7)] = [:]
            
            for event in track.events {
                let deltaTicks = getDeltaTicks(from: event)
                let deltaTime = (Double(deltaTicks) / ticksPerBeat) * (60.0 / currentTempoBPM)
                currentTime += deltaTime
                
                switch event {
                case .noteOn(_, let noteOn):
                    let noteNum = Int(noteOn.note.number)
                    switch noteOn.velocity {
                    case .midi1(let vel):
                        if vel > 0 {
                            activeNotes[noteNum] = (currentTime, vel)
                        } else {
                            if let (startTime, startVel) = activeNotes[noteNum] {
                                if startVel > confidenceThreshold {
                                    noteEvents.append(NoteEvent(
                                        noteName: midiNumberToName(noteNum),
                                        midiNumber: noteNum,
                                        startTime: startTime,
                                        duration: currentTime - startTime
                                    ))
                                }
                                activeNotes.removeValue(forKey: noteNum)
                            }
                        }
                    default: break
                    }
                    
                case .noteOff(_, let noteOff):
                    let noteNum = Int(noteOff.note.number)
                    if let (startTime, startVel) = activeNotes[noteNum] {
                        if startVel > confidenceThreshold {
                            noteEvents.append(NoteEvent(
                                noteName: midiNumberToName(noteNum),
                                midiNumber: noteNum,
                                startTime: startTime,
                                duration: currentTime - startTime
                            ))
                        }
                        activeNotes.removeValue(forKey: noteNum)
                    }
                    
                default: break
                }
            }
        }
        return noteEvents.sorted { $0.startTime < $1.startTime }
    }
    
    private func getDeltaTicks(from event: MIDIFileEvent) -> Int {
        let delta: MIDIFileEvent.DeltaTime
        
        switch event {
        case .noteOn(let d, _): delta = d
        case .noteOff(let d, _): delta = d
        case .cc(let d, _): delta = d
        case .programChange(let d, _): delta = d
        case .pitchBend(let d, _): delta = d
        default: return 0
        }
        
        switch delta {
        case .ticks(let t): return Int(t)
        default: return 0
        }
    }
    
    private func midiNumberToName(_ number: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (number / 12) - 1
        let name = noteNames[number % 12]
        return "\(name)\(octave)"
    }
}
