import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var scanner = CameraScannerManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Khung quét Camera
                ZStack {
                    CameraPreview(session: scanner.captureSession)
                        .edgesIgnoringSafeArea(.top)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(scanner.flashFeedback ? Color.green : Color.white.opacity(0.7), lineWidth: scanner.flashFeedback ? 4 : 2)
                        .frame(height: 120)
                        .padding(.horizontal, 32)
                        .animation(.easeInOut(duration: 0.15), value: scanner.flashFeedback)
                    
                    Text("Đưa camera vào vị trí số PO")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(.top, 90)
                }
                .frame(height: UIScreen.main.bounds.height * 0.35)
                
                // Danh sách mã PO đã bắt được
                VStack(spacing: 12) {
                    HStack {
                        Text("Tên tập:")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        TextField("VD: Tập số 1", text: $scanner.currentBatchName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    HStack {
                        Text("Đã quét: \(scanner.scannedPOs.count) PO")
                            .font(.headline)
                        Spacer()
                        if !scanner.scannedPOs.isEmpty {
                            Button("Xoá hết") { scanner.clearData() }
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    
                    if !scanner.syncMessage.isEmpty {
                        Text(scanner.syncMessage)
                            .font(.caption)
                            .bold()
                            .foregroundColor(scanner.syncMessage.contains("✅") ? .green : .red)
                    }
                    
                    List {
                        ForEach(scanner.scannedPOs) { item in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(item.poNumber)
                                    .font(.system(.body, design: .monospaced))
                                    .bold()
                                Spacer()
                                Text(item.timestamp)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                // Nút Đẩy dữ liệu
                Button(action: { scanner.pushToGoogleSheets() }) {
                    HStack {
                        if scanner.isSyncing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "icloud.and.arrow.up.fill")
                        }
                        Text(scanner.isSyncing ? "Đang gửi..." : "Lưu vào Google Sheets")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(scanner.scannedPOs.isEmpty ? Color.gray.opacity(0.4) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding()
                }
                .disabled(scanner.scannedPOs.isEmpty || scanner.isSyncing)
            }
            .navigationTitle("Native PO Scanner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CameraPreview: UIViewControllerRepresentable {
    let session: AVCaptureSession
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        vc.view.layer.addSublayer(layer)
        DispatchQueue.main.async { layer.frame = vc.view.bounds }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let layer = uiViewController.view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiViewController.view.bounds
        }
    }
}
