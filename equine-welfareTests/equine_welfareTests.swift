import XCTest
import Testing
@testable import equine_welfare
class equine_welfareTests: XCTestCase {
    
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
    
// Requirment_Model
    
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
    
// Assesment_Model
    
// Test that the Assessment is initialized with the correct default values.
    func testAssessmentInitialization() {
        let date = Date()
        let assessment = Assessment(vetName: "Dr. Smith", farmName: "Sunny Farms", visitDate: date)
            
        // Verify that the ID is generated.
        XCTAssertNotNil(assessment.id, "ID should not be nil")
        // Verify the vet name, farm name, and visit date.
        XCTAssertEqual(assessment.vetName, "Dr. Smith")
        XCTAssertEqual(assessment.farmName, "Sunny Farms")
        XCTAssertEqual(assessment.visitDate, date)
        // Verify that the assessment starts incomplete.
        XCTAssertFalse(assessment.isComplete, "isComplete should be false by default")
        // Verify that relationships are initialized as empty arrays.
        XCTAssertTrue(assessment.sections.isEmpty, "Sections should be empty initially")
        XCTAssertTrue(assessment.horses.isEmpty, "Horses should be empty initially")
        // Verify that sideNotes is nil.
        XCTAssertNil(assessment.sideNotes, "sideNotes should be nil by default")
    }
        
    // Test the formattedDate computed property.
    func testFormattedDate() {
        // Create a specific date.
        var components = DateComponents()
        components.year = 2023
        components.month = 3
        components.day = 15
        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create date from components")
            return
        }
            
        let assessment = Assessment(vetName: "Dr. Smith", farmName: "Sunny Farms", visitDate: date)
            
        // Format the date in the same way as in the Assessment.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MMM-dd"
        let expectedDate = formatter.string(from: date)
            
        XCTAssertEqual(assessment.formattedDate, expectedDate, "formattedDate should match the expected date string")
    }
        
    // Test the displayName computed property.
    func testDisplayName() {
        let date = Date()
        let assessment = Assessment(vetName: "Dr. Smith", farmName: "Sunny Farms", visitDate: date)

        let expectedDisplayName = "\(assessment.formattedDate)-\(assessment.vetName)-\(assessment.farmName)"
        XCTAssertEqual(assessment.displayName, expectedDisplayName, "displayName should correctly interpolate the formatted date, vetName, and farmName")
    }
        
    // Test adding related models (Sections and Horses) to the assessment.
    func testAssessmentRelationships() {
        let date = Date()
        let assessment = Assessment(vetName: "Dr. Smith", farmName: "Sunny Farms", visitDate: date)
            
        // Create a dummy Section.
        let dummySection = Section(id: 1, title: "Test Section")
            
        // Create a dummy Horse. Use the appropriate initializer from your Horse model.
        let dummyHorse = Horse(name: "Thunder",
                                age: 4,
                                color: "Brown",
                                sex: "Mare",
                                breed: "Quarter",
                                timeOnFarm: 10)
            
        // Simulate adding related models.
        assessment.sections.append(dummySection)
        assessment.horses.append(dummyHorse)
            
        XCTAssertEqual(assessment.sections.count, 1, "There should be one section in the assessment")
        XCTAssertEqual(assessment.horses.count, 1, "There should be one horse in the assessment")
    }

// Section_Model
    
// Test that the Section initializer sets the properties correctly.
    func testSectionInitialization() {
        let section = Section(id: 1, title: "Test Section")

        // Verify the basic properties.
        XCTAssertEqual(section.id, 1, "Section id should be 1")
        XCTAssertEqual(section.title, "Test Section", "Section title should match")
        XCTAssertFalse(section.isApplicable, "isApplicable should be false by default")

        // Verify the default collections and values.
        XCTAssertTrue(section.subsections.isEmpty, "subsections should be empty by default")
        XCTAssertEqual(section.infoIconClicks, 0, "infoIconClicks should be 0 by default")
        XCTAssertNil(section.assessment, "assessment should be nil by default")
    }

    // Test equality and hashability of Section.
    func testSectionEqualityAndHashing() {
        // Create two sections with the same id but different property values.
        let section1 = Section(id: 1, title: "Test Section", isApplicable: true)
        let section2 = Section(id: 1, title: "Test Section", isApplicable: false)
        let section3 = Section(id: 2, title: "Another Section")

        // They should be equal because equality is based on the id.
        XCTAssertEqual(section1, section2, "Sections with the same id should be equal")
        XCTAssertEqual(section1.hashValue, section2.hashValue, "Hash values should be equal for sections with the same id")

        // A section with a different id should not be equal.
        XCTAssertNotEqual(section1, section3, "Sections with different ids should not be equal")
    }
// Test updating some properties.
    func testSectionPropertyUpdates() {
        let section = Section(id: 1, title: "Test Section")
        section.isApplicable = true
        section.infoIconClicks = 5

        XCTAssertTrue(section.isApplicable, "isApplicable should be updated to true")
        XCTAssertEqual(section.infoIconClicks, 5, "infoIconClicks should be updated to 5")
    }
    
// Subsection_Model
    
// Test that the Subsection initializer sets the name and defaults the requirements array.
    func testSubsectionInitialization() {
        let subsection = Subsection(name: "Test Subsection")

        // Verify that the name is set correctly.
        XCTAssertEqual(subsection.name, "Test Subsection", "Subsection name should be set as provided")
        // Verify that the requirements array is empty upon initialization.
        XCTAssertTrue(subsection.requirements.isEmpty, "requirements should be empty by default")
    }

    // Test adding a Requirement to the Subsection.
    func testSubsectionAddRequirement() {
        let subsection = Subsection(name: "Test Subsection")
        let requirement = Requirement(text: "Ensure safety measures")

        // Append the requirement to the subsection.
        subsection.requirements.append(requirement)

        // Verify that the requirements array now contains one requirement.
        XCTAssertEqual(subsection.requirements.count, 1, "requirements should contain one item after appending a requirement")
        XCTAssertEqual(subsection.requirements.first?.text, "Ensure safety measures", "The requirement text should match")
    }
//Compliance Status
        
// Test that the raw values are correctly set.
    func testRawValues() {
        XCTAssertEqual(ComplianceStatus.compliant.rawValue, "Compliant")
        XCTAssertEqual(ComplianceStatus.notCompliant.rawValue, "Not Compliant")
        XCTAssertEqual(ComplianceStatus.notApplicable.rawValue, "N/A")
    }

    // Test that all cases are included in the allCases array.
    func testCaseIterable() {
        let allCases = ComplianceStatus.allCases
        XCTAssertEqual(allCases.count, 3, "There should be three cases")
        XCTAssertTrue(allCases.contains(.compliant))
        XCTAssertTrue(allCases.contains(.notCompliant))
        XCTAssertTrue(allCases.contains(.notApplicable))
    }

    // Test Codable conformance: encoding and decoding.
    func testCodableConformance() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test encoding: encode one of the cases to JSON.
        let encodedData = try encoder.encode(ComplianceStatus.compliant)
        let jsonString = String(data: encodedData, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"Compliant\"")

        // Test decoding: decode the JSON back to a ComplianceStatus case.
        let decodedCase = try decoder.decode(ComplianceStatus.self, from: encodedData)
        XCTAssertEqual(decodedCase, ComplianceStatus.compliant)
    }
}
