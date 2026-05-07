import SwiftUI
import AVFoundation
import Vision
import CoreImage
import UIKit

// MARK: - Camera QR Scanner

/// 카메라로 QR 코드를 실시간 스캔. 첫 인식 시 `onScan` 호출 후 자동 종료.
struct CameraQRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        let onScan: (String) -> Void
        let onCancel: () -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func scanner(_ controller: ScannerViewController, didFind code: String) {
            guard !didScan else { return }
            didScan = true
            onScan(code)
        }

        func scannerDidCancel(_ controller: ScannerViewController) {
            onCancel()
        }
    }
}

// MARK: - Image QR Decoder

enum QRDecoder {
    /// 앨범에서 선택한 UIImage 로부터 QR payload 를 추출. 여러 개면 첫 번째.
    /// CIDetector(고정밀)을 우선 시도하고, 실패 시 Vision 으로 fallback.
    static func decode(_ image: UIImage) -> String? {
        if let value = decodeWithCIDetector(image) { return value }
        if let value = decodeWithVision(image) { return value }
        return nil
    }

    private static func decodeWithCIDetector(_ image: UIImage) -> String? {
        // 정확도/방향 조합별로 결과가 달라질 수 있어 후보 이미지를 여러 개 만든 뒤 시도.
        let candidates: [CIImage] = {
            var arr: [CIImage] = []
            if let cg = image.cgImage {
                let base = CIImage(cgImage: cg)
                arr.append(base)
                arr.append(base.oriented(cgImagePropertyOrientation(image.imageOrientation)))
            }
            if let fromUIImage = CIImage(image: image) {
                arr.append(fromUIImage)
            }
            return arr
        }()

        let context = CIContext(options: nil)
        for accuracy in [CIDetectorAccuracyHigh, CIDetectorAccuracyLow] {
            guard let detector = CIDetector(
                ofType: CIDetectorTypeQRCode,
                context: context,
                options: [CIDetectorAccuracy: accuracy]
            ) else { continue }

            for ciImage in candidates {
                let features = detector.features(in: ciImage)
                for case let feature as CIQRCodeFeature in features {
                    if let s = feature.messageString, !s.isEmpty { return s }
                }
            }
        }
        return nil
    }

    private static func decodeWithVision(_ image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        return request.results?
            .compactMap { ($0 as? VNBarcodeObservation)?.payloadStringValue }
            .first { !$0.isEmpty }
    }

    private static func cgImagePropertyOrientation(_ ui: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch ui {
        case .up:            return .up
        case .upMirrored:    return .upMirrored
        case .down:          return .down
        case .downMirrored:  return .downMirrored
        case .left:          return .left
        case .leftMirrored:  return .leftMirrored
        case .right:         return .right
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}

// MARK: - AVFoundation Scanner

protocol ScannerViewControllerDelegate: AnyObject {
    func scanner(_ controller: ScannerViewController, didFind code: String)
    func scannerDidCancel(_ controller: ScannerViewController)
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "com.union.qr.session")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
        configureUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    private func configureUI() {
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("취소", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)

        let guide = UIView()
        guide.layer.borderColor = UIColor.white.cgColor
        guide.layer.borderWidth = 2
        guide.layer.cornerRadius = 16
        guide.backgroundColor = .clear
        guide.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guide)

        let hint = UILabel()
        hint.text = "QR 코드를 사각형 안에 맞추세요"
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 15, weight: .medium)
        hint.textAlignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            guide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            guide.widthAnchor.constraint(equalToConstant: 260),
            guide.heightAnchor.constraint(equalToConstant: 260),

            hint.topAnchor.constraint(equalTo: guide.bottomAnchor, constant: 24),
            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    @objc private func cancelTapped() {
        delegate?.scannerDidCancel(self)
    }

    // MARK: AVCaptureMetadataOutputObjectsDelegate

    /// `setMetadataObjectsDelegate(self, queue: .main)` 로 등록했으므로 콜백은 main 스레드.
    /// 프로토콜 자체는 nonisolated 라 Swift 6 동시성 검사를 통과시키려면
    /// 이 메서드를 nonisolated 로 두고 `MainActor.assumeIsolated` 로 본체에 접근한다.
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        MainActor.assumeIsolated {
            self.sessionQueue.async { [weak self] in
                self?.session.stopRunning()
            }
            self.delegate?.scanner(self, didFind: value)
        }
    }
}
