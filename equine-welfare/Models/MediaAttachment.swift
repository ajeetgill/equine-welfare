import Foundation
import SwiftData
import SwiftUI

@Model
class MediaAttachment : Identifiable{
    var id: UUID
    var data: Data
    var mediaType: MediaType
    var creationDate: Date
    
    init(imageData: Data) {
        self.id = UUID()
        self.data = imageData
        self.mediaType = .image
        self.creationDate = Date()
    }
    
    init(videoData: Data) {
        self.id = UUID()
        self.data = videoData
        self.mediaType = .video
        self.creationDate = Date()
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
