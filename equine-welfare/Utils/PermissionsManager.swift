import AVFoundation
import SwiftUI

class PermissionsManager: ObservableObject {
    @Published var isCameraAuthorized = false
    @Published var isMicrophoneAuthorized = false
    @Published var showPermissionsAlert = false
    
    func checkAndRequestPermissions() async {
        // Check camera authorization
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        var newCameraAuth = false
        
        if cameraAuthStatus == .notDetermined {
            newCameraAuth = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            newCameraAuth = cameraAuthStatus == .authorized
        }
        
        // Check microphone authorization
        let microphoneAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        var newMicrophoneAuth = false
        
        if microphoneAuthStatus == .notDetermined {
            newMicrophoneAuth = await AVCaptureDevice.requestAccess(for: .audio)
        } else {
            newMicrophoneAuth = microphoneAuthStatus == .authorized
        }
        
        // Capture as let for Swift 6 concurrency safety
        let cameraResult = newCameraAuth
        let microphoneResult = newMicrophoneAuth

        // Update all UI state on the main thread
        await MainActor.run {
            self.isCameraAuthorized = cameraResult
            self.isMicrophoneAuthorized = microphoneResult
            // Only show alert if permissions were explicitly denied
            self.showPermissionsAlert = (cameraAuthStatus == .denied || microphoneAuthStatus == .denied)
        }
    }
    
    func checkCurrentPermissionStatus() {
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let microphoneAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        // Update all UI state on the main thread
        DispatchQueue.main.async {
            self.isCameraAuthorized = cameraAuthStatus == .authorized
            self.isMicrophoneAuthorized = microphoneAuthStatus == .authorized
            // Remove automatic alert setting - let the MainScreen handle when to show the alert
        }
    }
    
    func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
} 