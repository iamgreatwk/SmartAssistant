import AVFoundation
import UIKit
import Combine

/// 摄像头服务 — 管理前后摄像头、拍照、实时预览
class CameraService: NSObject, ObservableObject {
    
    @Published var isRunning = false
    @Published var isFrontCamera = true
    @Published var capturedImage: UIImage?
    @Published var errorMessage: String?
    
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var currentCamera: AVCaptureDevice?
    
    private let sessionQueue = DispatchQueue(label: "com.smartassistant.camera.session")
    
    override init() {
        super.init()
        session.sessionPreset = .photo
    }
    
    // MARK: - 启动/停止
    
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.session.isRunning else { return }
            
            self.configureSession()
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
            }
        }
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
    
    // MARK: - 切换摄像头
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newPosition: AVCaptureDevice.Position = self.isFrontCamera ? .back : .front
            
            self.session.beginConfiguration()
            
            // 移除旧输入
            if let input = self.videoDeviceInput {
                self.session.removeInput(input)
            }
            
            // 添加新输入
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
                self.videoDeviceInput = input
                self.currentCamera = device
            }
            
            self.session.commitConfiguration()
            
            DispatchQueue.main.async {
                self.isFrontCamera.toggle()
            }
        }
    }
    
    // MARK: - 拍照
    
    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // MARK: - 配置会话
    
    private func configureSession() {
        session.beginConfiguration()
        
        // 添加视频输入
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.errorMessage = "无法访问摄像头" }
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
            videoDeviceInput = input
            currentCamera = device
        }
        
        // 添加照片输出
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
    }
    
    // MARK: - 获取相机预览层
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { self.errorMessage = "拍照失败: \(error.localizedDescription)" }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async { self.errorMessage = "图片处理失败" }
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = self.isFrontCamera ? image : image
        }
    }
}
