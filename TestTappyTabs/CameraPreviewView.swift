//
//  CameraPreviewView.swift
//  TestTappyTabs
//
//  Created by Carlos Mbendera on 21/11/2025.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    
    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.session = session
        return view
    }
    
    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        // Updates handled by the view itself
    }
    
    class PreviewNSView: NSView {
        var session: AVCaptureSession? {
            didSet {
                if let session = session {
                    previewLayer.session = session
                }
            }
        }
        
        private var previewLayer: AVCaptureVideoPreviewLayer!
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setupLayer()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupLayer()
        }
        
        private func setupLayer() {
            wantsLayer = true
            
            previewLayer = AVCaptureVideoPreviewLayer()
            previewLayer.videoGravity = .resizeAspectFill
            
            if let layer = self.layer {
                previewLayer.frame = layer.bounds
                layer.addSublayer(previewLayer)
            }
        }
        
        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }
}
