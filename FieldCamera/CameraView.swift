import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var camera = CameraController()
    @Environment(\.scenePhase) private var phase
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                CameraPreview(camera: camera).ignoresSafeArea()
                VStack(spacing: 12) {
                    HStack {
                        Text("FIELD CAMERA").font(.headline)
                        Spacer()
                        Text("1080p · 30 fps").font(.caption.monospaced())
                        if camera.recording { Text("● REC").foregroundStyle(.red) }
                    }
                    Spacer()
                    Text(camera.status).font(.callout).padding(8)
                        .background(.black.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 8))
                    if !camera.levels.isEmpty {
                        HStack {
                            Text("MIC").font(.caption)
                            ForEach(Array(camera.levels.enumerated()), id: \.offset) { index, db in
                                VStack(alignment: .leading, spacing: 3) {
                                    GeometryReader { bar in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(.white.opacity(0.2))
                                            Capsule().fill(db > -3 ? .red : .green)
                                                .frame(width: bar.size.width * CGFloat(max(0, min(1, (db + 60) / 60))))
                                        }
                                    }.frame(height: 8)
                                    Text("CH \(index + 1)  \(Int(db)) dBFS").font(.caption2.monospaced())
                                }
                            }
                        }.padding(8).background(.black.opacity(0.6))
                    }
                    HStack(spacing: 18) {
                        Text(String(format: "%.1f×", camera.zoom)).monospacedDigit()
                        Slider(value: Binding(get: { camera.zoom }, set: { camera.setZoom($0) }),
                               in: 1...camera.maxZoom).disabled(!camera.ready)
                        Button(action: { camera.toggleRecording() }) {
                            Image(systemName: camera.recording ? "stop.fill" : "circle.fill")
                                .font(.system(size: 30)).foregroundStyle(.red)
                                .frame(width: 64, height: 64).background(.white).clipShape(Circle())
                        }.disabled(!camera.ready || camera.busy)
                            .accessibilityLabel(camera.recording ? "Stop recording" : "Record")
                    }.padding(12).background(.black.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 16))
                    HStack {
                        Text("Tap picture to focus").font(.caption)
                        Spacer()
                        if camera.pendingCount > 0 {
                            Button("Save \(camera.pendingCount) clip(s)") { camera.retrySaves() }
                                .disabled(camera.recording || camera.busy)
                        }
                    }
                }.padding().foregroundStyle(.white)
            }
        }
        .task { camera.start() }
        .onChange(of: phase) { value in
            if value == .active { camera.start() }
            else if value == .background { camera.suspend() }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let camera: CameraController
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.layerView.session = camera.session
        view.layerView.videoGravity = .resizeAspectFill
        view.camera = camera
        view.addGestureRecognizer(UITapGestureRecognizer(target: view, action: #selector(PreviewView.focus(_:))))
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) { uiView.setNeedsLayout() }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var layerView: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    weak var camera: CameraController?
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let orientation = window?.windowScene?.interfaceOrientation else { return }
        let video: AVCaptureVideoOrientation
        switch orientation {
        case .landscapeLeft: video = .landscapeLeft
        case .landscapeRight: video = .landscapeRight
        case .portraitUpsideDown: video = .portraitUpsideDown
        default: video = .portrait
        }
        if let connection = layerView.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = video
        }
        camera?.setOrientation(video)
    }
    @objc func focus(_ gesture: UITapGestureRecognizer) {
        let point = layerView.captureDevicePointConverted(fromLayerPoint: gesture.location(in: self))
        camera?.focus(at: point)
    }
}
