import SwiftUI
import UIKit
import AVFoundation

// MARK: - 相机预览视图

struct CameraPreviewView: View {
    @StateObject private var cameraService = CameraService()
    @State private var capturedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 预览区域
                ZStack {
                    if let image = capturedImage {
                        // 显示拍摄的照片
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                        
                        VStack {
                            Spacer()
                            Button {
                                capturedImage = nil
                                cameraService.start()
                            } label: {
                                Label("重新拍照", systemImage: "arrow.counterclockwise")
                                    .font(.caption)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                            }
                            .padding(.bottom, 20)
                        }
                    } else {
                        // 实时预览
                        CameraPreview(cameraService: cameraService)
                            .onAppear {
                                cameraService.start()
                            }
                            .onDisappear {
                                cameraService.stop()
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.65)
                .background(Color.black)
                
                // 控制区域
                VStack(spacing: 16) {
                    // 拍照按钮
                    Button {
                        capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(capturedImage != nil)
                    
                    // 切换摄像头
                    HStack(spacing: 30) {
                        Button {
                            cameraService.switchCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        if let _ = capturedImage {
                            Button {
                                UIImageWriteToSavedPhotosAlbum(capturedImage!, nil, nil, nil)
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                .padding(.vertical, 20)
                .background(Color.black.opacity(0.9))
            }
            .navigationTitle("相机")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
    
    private func capturePhoto() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        cameraService.capturePhoto()
        
        // 延迟获取照片
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let image = cameraService.capturedImage {
                self.capturedImage = image
            }
        }
    }
}

// MARK: - UIKit 相机预览封装

struct CameraPreview: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = cameraService.getPreviewLayer()
        previewLayer.frame = view.frame
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.frame
        }
    }
}
