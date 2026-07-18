// PushAlarm — CameraPreviewView.swift
// UIViewRepresentable that hosts an AVCaptureVideoPreviewLayer.

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.setPreviewLayer(previewLayer)
    }

    // MARK: - Hosted UIView

    final class PreviewUIView: UIView {
        private var currentLayer: AVCaptureVideoPreviewLayer?

        func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
            // Remove previous if any
            currentLayer?.removeFromSuperlayer()
            currentLayer = layer
            layer.frame = bounds
            self.layer.insertSublayer(layer, at: 0)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            currentLayer?.frame = bounds
        }
    }
}
