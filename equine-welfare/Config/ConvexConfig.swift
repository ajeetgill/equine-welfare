import Foundation

enum ConvexConfig {
    static var deploymentURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "CONVEX_URL") as? String,
              !url.isEmpty else {
            fatalError("CONVEX_URL not found in Info.plist. Add it to your Secrets.xcconfig file.")
        }
        return url
    }
}
