import SwiftData
import Foundation

@Model
class Horse {
    @Attribute(.unique) var uuid: UUID
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
    @Attribute(.externalStorage) var abnormalPhotosData: [Data]
    
    // Inverse relationship to Assessment - using proper SwiftData syntax
    @Relationship(inverse: \Assessment.horses) var assessment: Assessment?
    
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
        abnormalPhotosData: [Data] = [],
        assessment: Assessment? = nil
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
        self.assessment = assessment
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

// For horses and other model objects that will be passed to NavigationLinks
extension Horse: Identifiable, Hashable {
    // If using SwiftData, Identifiable may already be implemented
    
    // Add hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
    
    public static func == (lhs: Horse, rhs: Horse) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
