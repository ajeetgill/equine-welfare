import MijickCamera
import SwiftUI

struct CustomCameraScreen: MCameraScreen {
    @ObservedObject var cameraManager: CameraManager
    let namespace: Namespace.ID
    let closeMCameraAction: () -> Void

    @State private var isFlashOn = false
    @State private var flashMode: CameraFlashMode = .off

    var body: some View {
        ZStack {
            // Camera preview
            createCameraOutputView()
                .ignoresSafeArea()

            // UI Overlay
            VStack {
                // Top controls
                HStack {
                    if !isRecording {
                        // Close button
                        Button(action: closeMCameraAction) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        Spacer()
                        // Camera switch button
                        Button(action: {
                            Task {
                                try? await setCameraPosition(
                                    cameraPosition == .back ? .front : .back)
                            }
                        }) {
                            Image(
                                systemName: "arrow.triangle.2.circlepath.camera"
                            )
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                        }
                    }
                }
                .padding(20)

                Spacer()

                // Bottom controls
                VStack(spacing: 30) {
                    // Recording timer
                    if isRecording {
                        if recordingTime.hours > 0 {
                            Text(
                                String(
                                    format: "%02d:%02d:%02d",
                                    recordingTime.hours, recordingTime.minutes,
                                    recordingTime.seconds)
                            )
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                        } else {
                            Text(
                                String(
                                    format: "%02d:%02d", recordingTime.minutes,
                                    recordingTime.seconds)
                            )
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                        }
                    }

                    HStack(alignment: .bottom) {

                        // Add Flash Mode button
                        Button(action: {
                            // CHANGE: Replace flashMode.next() with custom cycling logic
                            switch flashMode {
                            case .off:
                                flashMode = .on
                            case .on:
                                flashMode = .auto
                            case .auto:
                                flashMode = .off
                            }
                            setFlashMode(flashMode)
                        }) {
                            Image(
                                systemName: isRecording
                                    ? "noSign" : flashModeIcon
                            )
                            .foregroundColor(.white)
                            .font(.system(size: 30))
                            .frame(width: 64, height: 64)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                        }
                        .disabled(isRecording)
                        Spacer()

                        // Capture button
                        withAnimation {
                            VStack(spacing: 10) {
                                if !isRecording {
                                    HStack(spacing: 15) {
                                        Button(action: {
                                            setOutputType(.photo)
                                        }) {
                                            Image(systemName: "camera")
                                                .foregroundColor(
                                                    cameraOutputType == .photo
                                                        ? .yellow : .white
                                                )
                                                .font(
                                                    .system(
                                                        size: cameraOutputType
                                                            == .photo ? 25 : 20)
                                                )
                                        }
                                        .frame(
                                            width: cameraOutputType == .photo
                                                ? 46 : 44,
                                            height: cameraOutputType == .photo
                                                ? 46 : 44
                                        )
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())

                                        Button(action: {
                                            setOutputType(.video)
                                        }) {
                                            Image(systemName: "video")
                                                .foregroundColor(
                                                    cameraOutputType == .video
                                                        ? .yellow : .white
                                                )
                                                .font(
                                                    .system(
                                                        size: cameraOutputType
                                                            == .video ? 25 : 20)
                                                )
                                        }
                                        .frame(
                                            width: cameraOutputType == .video
                                                ? 46 : 44,
                                            height: cameraOutputType == .video
                                                ? 46 : 44
                                        )
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                    }
                                    .frame(width: 100, height: 50)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(50)
                                }

                                Button(action: captureOutput) {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(
                                                Color.white, lineWidth: 4
                                            )
                                            .frame(width: 75, height: 75)

                                        if isRecording {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.red)
                                                .frame(width: 30, height: 30)
                                        } else {
                                            Circle()
                                                .fill(
                                                    cameraOutputType == .photo
                                                        ? Color.white
                                                        : Color.red
                                                )
                                                .frame(width: 65, height: 65)
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                        if hasLight {
                            Button(action: {
                                isFlashOn.toggle()
                                try? setLightMode(isFlashOn ? .on : .off)
                            }) {
                                Image(
                                    systemName: isFlashOn
                                        ? "flashlight.on.fill"
                                        : "flashlight.off.fill"
                                )
                                .foregroundColor(
                                    isFlashOn ? .white.opacity(0.8) : .white
                                )
                                .font(.system(size: 30))
                                .frame(width: 64, height: 64)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 30)
            }
        }
    }

    private var flashModeIcon: String {
        switch flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        }
    }
}
