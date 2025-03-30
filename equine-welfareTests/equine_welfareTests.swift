import XCTest
import Testing
@testable import equine_welfare
class equine_welfareTests: XCTestCase {
    
//unit testing
//Horse_Model
    
    // Test that initialization sets the correct default values and properties.
    func testHorseInitialization() {
        // Create a Horse instance using the initializer.
        let horse = Horse(
            name: "Lightning",
            age: 5,
            color: "Black",
            sex: "Mare",
            breed: "Arabian",
            timeOnFarm: 12
        )

        // Verify that the uuid is generated and properties are set.
        XCTAssertNotNil(horse.uuid, "UUID should not be nil")
        XCTAssertEqual(horse.name, "Lightning")
        XCTAssertEqual(horse.age, 5)
        XCTAssertEqual(horse.color, "Black")
        XCTAssertEqual(horse.sex, "Mare")
        XCTAssertEqual(horse.breed, "Arabian")
        XCTAssertNil(horse.otherBreed, "otherBreed should be nil if not provided")
        XCTAssertEqual(horse.timeOnFarm, 12)
        XCTAssertEqual(horse.bcsScore, 3.0, "Default BCS score should be 4.0")
        XCTAssertEqual(horse.ageUnit, .years)
        XCTAssertEqual(horse.timeUnit, .years)
        XCTAssertNil(horse.photoData)
        XCTAssertNil(horse.assessment)
    }

    // Test equality and uniqueness based on uuid.
    func testHorseEquality() {
        let horse1 = Horse(
            name: "Lightning",
            age: 5,
            color: "Black",
            sex: "Mare",
            breed: "Arabian",
            timeOnFarm: 12
        )
        let horse2 = Horse(
            name: "Lightning",
            age: 5,
            color: "Black",
            sex: "Mare",
            breed: "Arabian",
            timeOnFarm: 12
        )

        XCTAssertNotEqual(horse1, horse2, "Different Horse instances should have unique UUIDs and thus not be equal")
    }

    func testHorseRelationships() {
        let mockMedia = MediaAttachment(imageData: Data())
        let horse = Horse(
            name: "Spirit",
            age: 3,
            color: "Brown",
            sex: "Stallion",
            breed: "Mustang",
            timeOnFarm: 6,
            photoData: mockMedia
        )

        XCTAssertNotNil(horse.photoData, "Photo data should be set")
    }
    
//Requirment_Model
    
// Test that the Requirement is initialized with the correct default values.
    func testRequirementInitialization() {
        let requirement = Requirement(text: "Ensure safety measures")

        // Verify the text property
        XCTAssertEqual(requirement.text, "Ensure safety measures")

        // Verify that optional properties are nil by default
        XCTAssertNil(requirement.complianceStatus)
        XCTAssertNil(requirement.nonComplianceReason)

        // Verify that mediaAttachments is initialized as an empty array
        XCTAssertTrue(requirement.mediaAttachments.isEmpty, "mediaAttachments should start empty")
    }

    // Test the relationship by adding a MediaAttachment to mediaAttachments.
    func testRequirementMediaAttachments() {
        let requirement = Requirement(text: "Check Equipment")

        // Create a dummy MediaAttachment.
        let dummyMedia = MediaAttachment(imageData: Data())

        // Simulate adding a media attachment.
        requirement.mediaAttachments.append(dummyMedia)

        // Verify that the mediaAttachments array now contains one item.
        XCTAssertEqual(requirement.mediaAttachments.count, 1, "mediaAttachments should have one item after adding a media attachment")
        XCTAssertNotNil(requirement.mediaAttachments.first, "The first media attachment should not be nil")
    }
    
}
