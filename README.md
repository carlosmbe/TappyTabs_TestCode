# TappyTabs

**Guitar tablature generation from video using computer vision and audio analysis.**

> ⚠️ **Prototype Notice**: This is an initial R&D implementation. The code is messy, experimental, and not intended for production use or public consumption. Refactoring will happen when time allows.

## Overview

TappyTabs is a macOS application that analyzes guitar playing videos and automatically generates tablature (tabs). It combines computer vision for fretboard detection with audio analysis to produce accurate guitar tabs.

The model's `.mlpackage` is too big for GitHub so here's a Google Drive link [TapToTab_640_Speed.mlpackage](https://drive.google.com/file/d/1sMi2sHucp-PLsYaDwFRWO1NP2clyjvOT/view?usp=sharing)

Huge shoutout to [Hanan Hindy](https://www.linkedin.com/in/hanan-hindy/) and their team for the awesome [TapToTab paper ](https://arxiv.org/abs/2409.08618)and sharing their dataset! It's a great read! 

## Features

### Two Operation Modes

1. **Real-Time Recording**
   - Record yourself playing guitar live
   - Real-time fretboard detection using Vision framework
   - Simultaneous audio capture
   - Generates tabs on-the-fly

2. **Upload Video**
   - Analyze pre-recorded guitar videos
   - Offline processing with visual playback
   - Frame-by-frame detection visualization
   - Multiple tab variation suggestions

### Core Capabilities

- **Computer Vision**: Detects finger positions on guitar fretboard using YOLOv8
- **Audio Analysis**: Uses Basic Pitch model for note detection
- **Tab Generation**: Maps detected notes to guitar tab notation
- **Multiple Variations**: Generates different playable interpretations of the same piece
- **Visual Feedback**: Real-time bounding boxes showing detected fret positions

## Beautiful Video

https://github.com/user-attachments/assets/630539c8-bf35-4215-991f-9115d8339934

## Technology Stack

- **Swift & SwiftUI**: Native macOS interface
- **AVFoundation**: Audio/video capture and processing
- **Vision Framework**: Real-time object detection
- **Core ML**: Machine learning model inference
- **Basic Pitch**: Audio-to-MIDI transcription

## Requirements
- [TapToTab_640_Speed.mlpackage (Too Big for GitHub)](https://drive.google.com/file/d/1sMi2sHucp-PLsYaDwFRWO1NP2clyjvOT/view?usp=sharing)
- Camera access (for real-time mode)
- Microphone access (for real-time mode)

## Current Limitations

- ⚠️ Prototype-quality code with minimal error handling
- ⚠️ No unit tests
- ⚠️ Hardcoded assumptions about guitar tuning
- ⚠️ Limited documentation
- ⚠️ Performance not optimized
- ⚠️ UI/UX needs polish

## How It Works

1. **Video Processing**: Detects finger positions on fretboard frame-by-frame
2. **Audio Analysis**: Extracts note pitches and timing from audio
3. **Data Fusion**: Combines vision and audio data with temporal alignment
4. **Tab Generation**: Maps detected notes to guitar tab notation with multiple variation suggestions

## Future Improvements

- Code refactoring and cleanup
- Comprehensive error handling
- Unit and integration tests
- Performance optimization
- Support for different guitar tunings
- Export functionality (PDF, text, etc.)
- Better UI/UX design
- Documentation

## Development Status

**Current Phase**: Research & Development prototype

This project serves as a proof-of-concept and testing ground for guitar tab generation algorithms. The codebase prioritizes experimentation over production readiness.

## Author

Carlos Mbendera
