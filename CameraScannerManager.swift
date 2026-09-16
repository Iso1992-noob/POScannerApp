import AVFoundation
import Vision
import SwiftUI
import AudioToolbox

class CameraScannerManager: NSObject, ObservableObject {
    @Published var scannedPOs: [POItem] = []
    @Published var currentBatchName: String = "Tập số 1"
    @Published var isSyncing: Bool = false
    @Published var syncMessage: String = ""
    @Published var flashFeedback: Bool = false
    
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var scannedSet: Set<String> = []
    
    // Regex lọc đúng 10 chữ số bắt đầu bằng 51
    private let poRegex = try! NSRegularExpression(pattern: "51\\d{8}")
    
    // DÁN LINK GOOGLE APPS SCRIPT VÀO ĐÂY
    private let googleSheetAPI = "https://script.google.com/macros/s/AKfycby_muQc_iw5IwOpFMRO3776CEcA59Q_DKDkQEhX0qUAtGmwYML_aDtfzx0NtFVthgE/exec"
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraFrameQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    func clearData() {
        scannedPOs.removeAll()
        scannedSet.removeAll()
        syncMessage = ""
    }
    
    func pushToGoogleSheets() {
        guard !scannedPOs.isEmpty, let url = URL(string: googleSheetAPI) else { return }
        isSyncing = true
        syncMessage = "Đang đẩy dữ liệu..."
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(scannedPOs)
            URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
                DispatchQueue.main.async {
                    self?.isSyncing = false
                    if let error = error {
                        self?.syncMessage = "❌ Lỗi: \(error.localizedDescription)"
                        return
                    }
                    self?.syncMessage = "✅ Đã lưu \(self?.scannedPOs.count ?? 0) PO!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.clearData()
                    }
                }
            }.resume()
        } catch {
            isSyncing = false
            syncMessage = "❌ Lỗi định dạng dữ liệu"
        }
    }
}

extension CameraScannerManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Native Vision API nhận diện chữ cực nhanh trên Neural Engine
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else { return }
            let fullText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            self?.extractPONumber(from: fullText)
        }
        
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? requestHandler.perform([request])
    }
    
    private func extractPONumber(from text: String) {
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = poRegex.matches(in: text, options: [], range: range)
        
        for match in matches {
            if let swiftRange = Range(match.range, in: text) {
                let foundPO = String(text[swiftRange])
                
                DispatchQueue.main.async {
                    if !self.scannedSet.contains(foundPO) {
                        self.scannedSet.insert(foundPO)
                        
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        let dateStr = formatter.string(from: Date())
                        
                        let newItem = POItem(poNumber: foundPO, batchName: self.currentBatchName, timestamp: dateStr)
                        self.scannedPOs.insert(newItem, at: 0)
                        
                        // Âm thanh Bíp + Rung Haptic
                        AudioServicesPlaySystemSound(1057)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        
                        self.flashFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.flashFeedback = false
                        }
                    }
                }
            }
        }
    }
}
