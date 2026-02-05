//
//  TabGeneratorEngine.swift
//  TestTappyTabs
//
//  Created by Carlos Mbendera on 23/11/2025.
//

import Foundation

struct TabNote {
    let string: Int // 0=E (low), 1=A, 2=D, 3=G, 4=B, 5=E (high)
    let fret: Int
    let note: String
    let startTime: TimeInterval
}

struct TabVariation {
    let id: Int
    let name: String
    let notes: [TabNote]
    let description: String
}

class TabGeneratorEngine {
    
    // Standard tuning: E2, A2, D3, G3, B3, E4
    private let standardTuning: [(string: Int, note: String, midiBase: Int)] = [
        (0, "E", 40), (1, "A", 45), (2, "D", 50), (3, "G", 55), (4, "B", 59), (5, "E", 64)
    ]
    
    func mapEventsToTab(audioNotes: [NoteEvent], visionHistory: [FretObservation]) -> [TabNote] {
        var tabNotes: [TabNote] = []
        
        // 1. Create a timeline lookup for faster access
        // Map roughly to 0.1s buckets or just iterate if list is small (185 frames is small)
        
        for audioNote in audioNotes {
            // 2. Find all technically possible positions for this pitch on a guitar
            // We allow up to fret 15 to cover common ranges
            let possiblePositions = findPossiblePositions(midiNote: audioNote.midiNumber)
            
            if possiblePositions.isEmpty { continue }
            
            // 3. Get relevant vision data for this specific note's duration
            // Expand window slightly to catch hand movements right before/after the pluck
            let searchStart = audioNote.startTime - 0.2
            let searchEnd = audioNote.startTime + 0.2 // Look at the attack transient primarily
            
            let relevantFrames = visionHistory.filter { $0.timestamp >= searchStart && $0.timestamp <= searchEnd }
            
            // Collect all frets seen during this note's window
            let seenFrets = Set(relevantFrames.flatMap { $0.frets })
            
            // 4. Score each possible position
            // Lower score is better
            let bestPos = possiblePositions.min { pos1, pos2 in
                let score1 = calculateScore(pos: pos1, seenFrets: seenFrets)
                let score2 = calculateScore(pos: pos2, seenFrets: seenFrets)
                return score1 < score2
            }
            
            if let best = bestPos {
                tabNotes.append(TabNote(
                    string: best.string,
                    fret: best.fret,
                    note: audioNote.noteName,
                    startTime: audioNote.startTime
                ))
            }
        }
        
        return tabNotes.sorted { $0.startTime < $1.startTime }
    }
    
    private func calculateScore(pos: (string: Int, fret: Int), seenFrets: Set<Int>) -> Int {
        var score = 0
        
        // CRITICAL: Distance from observed visual frets
        if !seenFrets.isEmpty {
            // Find distance to the nearest visually detected fret
            let dist = seenFrets.map { abs($0 - pos.fret) }.min() ?? 100
            
            if dist == 0 {
                // Exact match! Huge bonus (negative score)
                score -= 100
            } else if dist <= 2 {
                // Very close (within 2 frets) - likely correct hand position
                score += dist * 10
            } else {
                // Far away - highly unlikely
                score += dist * 100
            }
        } else {
            // No vision data? Fallback heuristics.
            // Prefer lower frets (0-5) generally
            score += pos.fret * 2
        }
        
        // Prefer open strings if no fret is detected close by
        if pos.fret == 0 {
            score -= 5
        }
        
        return score
    }
    
    private func findPossiblePositions(midiNote: Int) -> [(string: Int, fret: Int)] {
        var positions: [(string: Int, fret: Int)] = []
        let maxFret = 15 // Cap search range
        
        for stringInfo in standardTuning {
            let fret = midiNote - stringInfo.midiBase
            if fret >= 0 && fret <= maxFret {
                positions.append((stringInfo.string, fret))
            }
        }
        return positions
    }
    
    func generateASCIITab(tabNotes: [TabNote]) -> String {
        if tabNotes.isEmpty { return "No notes detected." }
        
        let stringNames = ["e", "B", "G", "D", "A", "E"]
        var lines: [String] = stringNames.map { "\($0)|" }
        
        // Sort by time
        let sortedNotes = tabNotes.sorted { $0.startTime < $1.startTime }
        
        for note in sortedNotes {
            let displayLine = 5 - note.string // Invert for tab display (0=High e in array)
            let fretStr = "\(note.fret)"
            
            // Pad all lines
            for i in 0..<6 {
                if i == displayLine {
                    lines[i] += "-\(fretStr)-"
                } else {
                    lines[i] += String(repeating: "-", count: fretStr.count + 2)
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    func generateASCIITabForVariation(_ variation: TabVariation) -> String {
        var output = "[\(variation.name)]\n"
        output += variation.description + "\n\n"
        output += generateASCIITab(tabNotes: variation.notes)
        return output
    }

    // MARK: - Tab Variations Feature
    
    /// Generate multiple valid tab variations for the user to choose from
    func generateTabVariations(audioNotes: [NoteEvent], visionHistory: [FretObservation]) -> [TabVariation] {
        print("🎸 === GENERATING TAB VARIATIONS ===")
        
        var variations: [TabVariation] = []
        
        // Variation 1: High String Preference
        let highStringNotes = mapEventsToTabWithStrategy(audioNotes: audioNotes, visionHistory: visionHistory, stringPreference: .high)
        if !highStringNotes.isEmpty {
            variations.append(TabVariation(
                id: 0,
                name: "High Strings",
                notes: highStringNotes,
                description: "Played on higher strings (e, B, G)"
            ))
        }
        
        // Variation 2: Low String Preference
        let lowStringNotes = mapEventsToTabWithStrategy(audioNotes: audioNotes, visionHistory: visionHistory, stringPreference: .low)
        if !lowStringNotes.isEmpty {
            variations.append(TabVariation(
                id: 1,
                name: "Low Strings",
                notes: lowStringNotes,
                description: "Played on lower strings (D, A, E)"
            ))
        }
        
        // Variation 3: Balanced
        let balancedNotes = mapEventsToTabWithStrategy(audioNotes: audioNotes, visionHistory: visionHistory, stringPreference: .balanced)
        if !balancedNotes.isEmpty {
            variations.append(TabVariation(
                id: 2,
                name: "Both",
                notes: balancedNotes,
                description: "Balanced across all strings"
            ))
        }
        
        print("✅ Generated \(variations.count) tab variations")
        return removeDuplicateVariations(variations)
    }
    
    enum StringPreference {
        case high, low, balanced
    }
    
    private func mapEventsToTabWithStrategy(audioNotes: [NoteEvent], visionHistory: [FretObservation], stringPreference: StringPreference) -> [TabNote] {
        var tabNotes: [TabNote] = []
        
        for audioNote in audioNotes {
            let possiblePositions = findPossiblePositions(midiNote: audioNote.midiNumber)
            if possiblePositions.isEmpty { continue }
            
            let searchStart = audioNote.startTime - 0.2
            let searchEnd = audioNote.startTime + 0.2
            let relevantFrames = visionHistory.filter { $0.timestamp >= searchStart && $0.timestamp <= searchEnd }
            let seenFrets = Set(relevantFrames.flatMap { $0.frets })
            
            let bestPos = possiblePositions.min { pos1, pos2 in
                calculateScoreWithPreference(pos: pos1, seenFrets: seenFrets, preference: stringPreference) <
                calculateScoreWithPreference(pos: pos2, seenFrets: seenFrets, preference: stringPreference)
            }
            
            if let best = bestPos {
                tabNotes.append(TabNote(string: best.string, fret: best.fret, note: audioNote.noteName, startTime: audioNote.startTime))
            }
        }
        
        return tabNotes.sorted { $0.startTime < $1.startTime }
    }
    
    private func calculateScoreWithPreference(pos: (string: Int, fret: Int), seenFrets: Set<Int>, preference: StringPreference) -> Int {
        var score = calculateScore(pos: pos, seenFrets: seenFrets)
        
        // Apply string preference
        switch preference {
        case .high:
            score += (5 - pos.string) * 10 // Prefer high strings
        case .low:
            score += pos.string * 10 // Prefer low strings
        case .balanced:
            score += abs(pos.string - 3) * 5 // Prefer middle
        }
        
        return score
    }
    
    private func removeDuplicateVariations(_ variations: [TabVariation]) -> [TabVariation] {
        var unique: [TabVariation] = []
        
        for variation in variations {
            let isDuplicate = unique.contains { existing in
                guard existing.notes.count == variation.notes.count else { return false }
                for (idx, note) in variation.notes.enumerated() {
                    if note.string != existing.notes[idx].string || note.fret != existing.notes[idx].fret {
                        return false
                    }
                }
                return true
            }
            
            if !isDuplicate {
                unique.append(variation)
            }
        }
        
        return unique
    }
    
} // End of Class
