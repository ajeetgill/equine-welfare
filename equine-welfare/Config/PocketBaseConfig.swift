import Foundation

enum PocketBaseConfig {
    static var baseURL: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "POCKETBASE_URL") as? String,
              !raw.isEmpty,
              let url = URL(string: raw) else {
            fatalError("POCKETBASE_URL not found in Info.plist. Add it to your Secrets.xcconfig file.")
        }
        return url
    }
}
