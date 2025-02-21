import SwiftData
import Foundation

@Model
class Horse {
    var name: String
    var age: Int
    var color: String
    var sex: String
    var breed: String
    var bodyConditionScore: Int
    var timeOnFarm: Int
    var comments: String
    var healthManagement: String
    var weight: Int
    var photoPath: String? // Path to the saved image
    
    init(name: String, age: Int, color: String, sex: String, breed: String, bodyConditionScore: Int, timeOnFarm: Int, comments: String, healthManagement: String, weight: Int) {
        self.name = name
        self.age = age
        self.color = color
        self.sex = sex
        self.breed = breed
        self.bodyConditionScore = bodyConditionScore
        self.timeOnFarm = timeOnFarm
        self.comments = comments
        self.healthManagement = healthManagement
        self.weight = weight
        self.photoPath = nil
    }
}