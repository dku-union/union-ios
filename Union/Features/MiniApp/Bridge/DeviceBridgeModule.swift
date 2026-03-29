import Foundation
import CoreLocation
import UIKit

// MARK: - Device Bridge Module
// SDK: Union.device.getLocation(), scanQRCode(), getClipboard(), setClipboard(), vibrate()

struct DeviceBridgeModule {

    func handle(action: String, params: [String: Any]) async throws -> Any? {
        switch action {
        case "getLocation":
            return try await getLocation()

        case "scanQRCode":
            // QR 스캔은 카메라 연동이 필요 — 캡스톤 데모에서는 mock 반환
            return ["result": "https://union.app/mock-qr-result"]

        case "getClipboard":
            return await MainActor.run { UIPasteboard.general.string ?? "" }

        case "setClipboard":
            let text = params["text"] as? String ?? ""
            await MainActor.run { UIPasteboard.general.string = text }
            return nil

        case "vibrate":
            let type = params["type"] as? String ?? "medium"
            await vibrate(type: type)
            return nil

        default:
            throw BridgeModuleError(code: "UNKNOWN_ACTION", message: "device.\(action) not found")
        }
    }

    // MARK: - Location (CLLocationManager one-shot)

    private func getLocation() async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = LocationDelegate(continuation: continuation)
            let manager = CLLocationManager()
            manager.delegate = delegate
            manager.desiredAccuracy = kCLLocationAccuracyBest

            // delegate를 retain하기 위해 associated object 사용
            objc_setAssociatedObject(manager, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

            switch manager.authorizationStatus {
            case .notDetermined:
                delegate.requestingAuth = true
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                continuation.resume(throwing: BridgeModuleError(
                    code: "PERMISSION_DENIED", message: "위치 권한이 거부되었습니다"
                ))
            }
        }
    }

    // MARK: - Vibrate (UIImpactFeedbackGenerator)

    @MainActor
    private func vibrate(type: String) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = switch type {
        case "light": .light
        case "heavy": .heavy
        default: .medium
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - CLLocationManager Delegate (one-shot)

private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var continuation: CheckedContinuation<[String: Any], Error>?
    var requestingAuth = false

    init(continuation: CheckedContinuation<[String: Any], Error>) {
        self.continuation = continuation
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
        ])
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(throwing: BridgeModuleError(
            code: "LOCATION_ERROR", message: error.localizedDescription
        ))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard requestingAuth else { return }
        requestingAuth = false

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            guard let cont = continuation else { return }
            continuation = nil
            cont.resume(throwing: BridgeModuleError(
                code: "PERMISSION_DENIED", message: "위치 권한이 거부되었습니다"
            ))
        default:
            break
        }
    }
}
