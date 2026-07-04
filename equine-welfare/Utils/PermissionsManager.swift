import AVFoundation
import SwiftUI

@MainActor
@Observable
class PermissionsManager {
    var isCameraAuthorized = false
    var isMicrophoneAuthorized = false
    var showPermissionsAlert = false

    nonisolated init() {}

    func checkAndRequestPermissions() async {
        // Check camera authorization
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let newCameraAuth: Bool
        if cameraAuthStatus == .notDetermined {
            newCameraAuth = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            newCameraAuth = cameraAuthStatus == .authorized
        }

        // Check microphone authorization
        let microphoneAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let newMicrophoneAuth: Bool
        if microphoneAuthStatus == .notDetermined {
            newMicrophoneAuth = await AVCaptureDevice.requestAccess(for: .audio)
        } else {
            newMicrophoneAuth = microphoneAuthStatus == .authorized
        }

        isCameraAuthorized = newCameraAuth
        isMicrophoneAuthorized = newMicrophoneAuth
        // Only show the alert if permissions were explicitly denied.
        showPermissionsAlert = (cameraAuthStatus == .denied || microphoneAuthStatus == .denied)
    }

    func checkCurrentPermissionStatus() {
        isCameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        isMicrophoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        // The caller decides when to surface the alert.
    }

    func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
