import SwiftData
import Foundation
import SwiftUI

@Model
class MediaAttachment {
    var id: UUID
    var imageData: Data
    var createdAt: Date
    
    init(imageData: Data) {
        self.id = UUID()
        self.imageData = imageData
        self.createdAt = Date()
    }
}

enum MediaType: String, Codable {
    case image
    case video
    
    var fileExtension: String {
        switch self {
        case .image:
            return "jpg"
        case .video:
            return "mp4"
        }
    }
    
    var mimeType: String {
        switch self {
        case .image:
            return "image/jpeg"
        case .video:
            return "video/mp4"
        }
    }
}
