import XCTest

final class Horse_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false

    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    @MainActor
    func testAddingHorse() throws {
        let app = XCUIApplication()
        app.launch()

        // missing some steps, need to press on the top left navigate button then Horses then to the add horses button

        let addButton = app.buttons["Add Horse"]//  need to navigate to the add horse button still incorrect here
        XCTAssertTrue(addButton.exists, "Add Horse button should exist") // check if the add horse exists
        addButton.tap() // taps

        let nameField = app.textFields["Name"]
        let breedField = app.textFields["Breed"] // fills out the fields still incorrect needs to tap each field first
        let timeField = app.textFields["Time"]

        XCTAssertTrue(nameField.exists, "Name field should exist")
        XCTAssertTrue(breedField.exists, "Breed field should exist") //  check if the fields exist
        XCTAssertTrue(timeField.exists, "Time field should exist")

        nameField.tap()
        nameField.typeText("Test Horse")

        breedField.tap()
        breedField.typeText("Test Breed") // taps each field

        timeField.tap()
        timeField.typeText("3") // field  is wrong

        let submitButton = app.buttons["Add Horse"]
        XCTAssertTrue(submitButton.exists, "Submit button should exist") // checks for the add button to complete the test and add the horse still incorrect
        submitButton.tap()

        // Verify the horse is added
        let newHorse = app.staticTexts["Test Horse"]
        XCTAssertTrue(newHorse.exists, "New horse should be in the list") // might remove this part
    }
}
