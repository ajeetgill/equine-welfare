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
    var notes: String?
    var ageUnit: AgeUnit
    var timeUnit: TimeUnit
    
    @Relationship(deleteRule: .cascade) var photoData: MediaAttachment?
    @Relationship(deleteRule: .cascade) var frontPhotoData: MediaAttachment?
    @Relationship(deleteRule: .cascade) var rightPhotoData: MediaAttachment?
    @Relationship(deleteRule: .cascade) var backPhotoData: MediaAttachment?
    @Relationship(deleteRule: .cascade) var leftPhotoData: MediaAttachment?
    
    @Relationship(deleteRule: .cascade) var abnormalPhotosData: [MediaAttachment] = []
    
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
        photoData: MediaAttachment? = nil,
        notes: String? = nil,
        ageUnit: AgeUnit = .years,
        timeUnit: TimeUnit = .years,
        frontPhotoData: MediaAttachment? = nil,
        rightPhotoData: MediaAttachment? = nil,
        backPhotoData: MediaAttachment? = nil,
        leftPhotoData: MediaAttachment? = nil,
        abnormalPhotosData: [MediaAttachment] = [],
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

extension Horse: Identifiable, Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
    
    public static func == (lhs: Horse, rhs: Horse) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
