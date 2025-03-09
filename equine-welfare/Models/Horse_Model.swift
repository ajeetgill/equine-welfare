import SwiftData
import Foundation

@Model
class Horse {
    var uuid: UUID
    var name: String
    var age: Int
    var color: String
    var sex: String
    var breed: String
    var otherBreed: String?
    var timeOnFarm: Int  // Months
    var bcsScore: Double
    var photoData: Data?
    var notes: String?
    var ageUnit: AgeUnit
    var timeUnit: TimeUnit
    
    // Add these properties for body photos
    var frontPhotoData: Data?
    var rightPhotoData: Data?
    var backPhotoData: Data?
    var leftPhotoData: Data?
    
    // Add this property for abnormal findings photos
    var abnormalPhotosData: [Data] = []
    
    init(
        name: String,
        age: Int,
        color: String,
        sex: String,
        breed: String,
        otherBreed: String? = nil,
        timeOnFarm: Int,
        bcsScore: Double = 3.0,
        photoData: Data? = nil,
        notes: String? = nil,
        ageUnit: AgeUnit = .years,
        timeUnit: TimeUnit = .days,
        frontPhotoData: Data? = nil,
        rightPhotoData: Data? = nil,
        backPhotoData: Data? = nil,
        leftPhotoData: Data? = nil,
        abnormalPhotosData: [Data] = []
    ) {
        self.uuid = UUID()
        self.name = name
        self.age = age
        self.color = color
        self.sex = sex
        self.breed = breed
        self.otherBreed = otherBreed
        self.timeOnFarm = timeOnFarm
        self.bcsScore = bcsScore
        self.photoData = photoData
        self.notes = notes
        self.ageUnit = ageUnit
        self.timeUnit = timeUnit
        self.frontPhotoData = frontPhotoData
        self.rightPhotoData = rightPhotoData
        self.backPhotoData = backPhotoData
        self.leftPhotoData = leftPhotoData
        self.abnormalPhotosData = abnormalPhotosData
    }
}

enum AgeUnit: String, CaseIterable, Codable {
    case years = "years"
    case months = "months"
    case weeks = "weeks"
    case days = "days"
}

enum TimeUnit: String, CaseIterable, Codable {
    case years = "years"
    case months = "months"
    case weeks = "weeks"
    case days = "days"
}