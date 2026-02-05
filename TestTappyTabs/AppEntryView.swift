//
//  AppEntryView.swift
//  TestTappyTabs
//
//  Created by Carlos Mbendera on 05/02/2026.
//

import SwiftUI

struct AppEntryView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                        
                        Text("TappyTabs")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Guitar tablature from video")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                    
                    // Mode cards
                    VStack(spacing: 20) {
                        ModeCard(
                            icon: "video.fill",
                            title: "Real-Time Recording",
                            description: "Record yourself playing and generate tabs live",
                            color: .blue,
                            destination: AnyView(IntegratedTranscriptionView())
                        )
                        
                        ModeCard(
                            icon: "film",
                            title: "Upload Video",
                            description: "Analyze pre-recorded guitar videos offline",
                            color: .purple,
                            destination: AnyView(TestView())
                        )
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Footer
                    Text("Choose a mode to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
        }
    }
}

struct ModeCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 20) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(
                        Circle()
                            .fill(color.gradient)
                    )
                
                // Text content
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppEntryView()
}
