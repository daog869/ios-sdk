import SwiftUI
import AVFoundation
import SwiftData

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QRScannerViewModel()
    
    var body: some View {
        ZStack {
            QRCameraView(
                session: viewModel.session,
                delegate: viewModel
            )
            .ignoresSafeArea()
            
            VStack {
                Text("Scan QR Code")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                if let error = viewModel.error {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.toggleTorch()
                } label: {
                    Image(systemName: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                }
                .foregroundStyle(.white)
            }
        }
        .sheet(item: $viewModel.scannedCode) { (code: ScannedQRCode) in
            NavigationView {
                PaymentView(
                    paymentMethod: PaymentMethod.qrCode,
                    prefillData: code.paymentData
                )
            }
        }
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
    }
}

struct QRCameraView: UIViewRepresentable {
    let session: AVCaptureSession
    let delegate: AVCaptureMetadataOutputObjectsDelegate
    
    func makeUIView(context: Context) -> QRCameraPreviewView {
        let view = QRCameraPreviewView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: QRCameraPreviewView, context: Context) {
        uiView.previewLayer?.frame = uiView.bounds
    }
}

class QRCameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

@preconcurrency
class QRScannerViewModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    @Published var error: String?
    @Published var scannedCode: ScannedQRCode?
    @Published var isTorchOn = false
    private var device: AVCaptureDevice?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            error = "Camera not available"
            return
        }
        self.device = device
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.addInput(input)
            
            let output = AVCaptureMetadataOutput()
            session.addOutput(output)
            
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func startScanning() {
        guard !session.isRunning else { return }
        session.startRunning()
    }
    
    func stopScanning() {
        guard session.isRunning else { return }
        session.stopRunning()
    }
    
    func toggleTorch() {
        guard let device = device,
              device.hasTorch,
              device.isTorchAvailable else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = isTorchOn ? .off : .on
            device.unlockForConfiguration()
            isTorchOn.toggle()
        } catch {
            self.error = "Could not toggle torch"
        }
    }
    
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let qrCode = metadataObject.stringValue,
              let paymentData = parseQRCode(qrCode) else {
            return
        }
        
        scannedCode = ScannedQRCode(id: UUID(), paymentData: paymentData)
        stopScanning()
    }
    
    private func parseQRCode(_ code: String) -> PaymentData? {
        // In a real app, implement proper QR code format parsing
        // Example format: "PAY|MERCHANT|AMOUNT|REFERENCE"
        let components = code.split(separator: "|")
        guard components.count == 4,
              components[0] == "PAY",
              let amount = Decimal(string: String(components[2])) else {
            return nil
        }
        
        return PaymentData(
            merchantName: String(components[1]),
            amount: amount,
            reference: String(components[3])
        )
    }
}

struct ScannedQRCode: Identifiable {
    let id: UUID
    let paymentData: PaymentData
}

#Preview {
    NavigationView {
        QRScannerView()
            .modelContainer(for: Transaction.self, inMemory: true)
    }
} 