//
//  DetectionOverlayView.swift
//  TestTappyTabs
//
//  Created by Carlos Mbendera on 21/11/2025.
//

import SwiftUI

struct DetectionOverlayView: View {
    let detections: [Detection]
    let viewSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(detections) { detection in
                    let rect = convertBoundingBox(detection.boundingBox, to: geometry.size)
                    
                    ZStack(alignment: .topLeading) {
                        // Bounding box
                        Rectangle()
                            .stroke(Color.green, lineWidth: 3)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                        
                        // Label with confidence
                        Text("\(detection.label) \(Int(detection.confidence * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.green.opacity(0.7))
                            .cornerRadius(4)
                            .position(x: rect.minX + 50, y: rect.minY - 15)
                    }
                }
            }
        }
    }
    
    // Convert Vision's normalized coordinates (0-1) to view coordinates
    // Vision uses bottom-left origin, SwiftUI uses top-left
    private func convertBoundingBox(_ boundingBox: CGRect, to size: CGSize) -> CGRect {
        let x = boundingBox.origin.x * size.width
        let y = (1 - boundingBox.origin.y - boundingBox.height) * size.height
        let width = boundingBox.width * size.width
        let height = boundingBox.height * size.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
