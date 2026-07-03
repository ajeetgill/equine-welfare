//
//  NavigationFlowUITests.swift
//  equine-welfareUITests
//
//  Exercises the unified navigation: root stack -> assessment workspace
//  (NavigationSplitView) -> horses sub-stack. On a compact (iPhone) device
//  this is the arrangement that previously broke via nested NavigationStacks,
//  so this test is the guard against that regression.
//

import XCTest

final class NavigationFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStartAssessmentThenHorsesAddFlow() throws {
        let app = XCUIApplication()
        // Dismiss any system permission alert (camera/mic) automatically.
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
            for label in ["Allow", "OK", "Allow While Using App"] {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }
            return false
        }
        app.launch()
        app.tap() // trigger any pending interruption monitor

        // Fill the new-assessment form so "Start Assessment" enables.
        let vet = app.textFields["Veterinarian Name"]
        XCTAssertTrue(vet.waitForExistence(timeout: 10), "Vet name field missing")
        vet.tap()
        vet.typeText("Dr. Test")

        let farm = app.textFields["Farm Name"]
        XCTAssertTrue(farm.waitForExistence(timeout: 5), "Farm name field missing")
        farm.tap()
        farm.typeText("Test Farm")

        let start = app.buttons["Start Assessment"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        // The workspace is a NavigationSplitView; its sidebar is hidden by
        // default in several presentations. Reveal it before selecting a pane:
        //  - iPad portrait: a "Show Sidebar" toggle in the nav bar.
        //  - iPhone compact: detail shows first with an "Assessment" back button.
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                      "Workspace did not present")
        if app.buttons["Show Sidebar"].exists {
            app.buttons["Show Sidebar"].tap()
        } else if app.buttons["Assessment"].exists {
            app.buttons["Assessment"].tap()
        }

        // The sidebar list exposes the panes; find the Horses entry.
        let horses = firstHittable(app, label: "Horses")
        XCTAssertTrue(horses.waitForExistence(timeout: 10),
                      "Workspace sidebar 'Horses' entry not found")
        horses.tap()

        // Horses pane should present with its Add button.
        let addButton = app.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10),
                      "'Add' button not found — horses pane did not present")

        // Tapping Add shows the horse form in the detail column (selection-based,
        // not a push). The form's Save button is unique to the add/edit detail,
        // so use it as the proof the detail appeared. On iPad portrait the panes
        // overlay may still be open, in which case the first tap only dismisses
        // it — so retry until the form appears.
        let saveButton = app.buttons["Save"]
        for _ in 0..<3 {
            if saveButton.waitForExistence(timeout: 3) { break }
            if addButton.exists { addButton.tap() }
        }
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5),
                      "Add-horse form did not appear after tapping Add")
    }

    /// Adds a named horse and verifies it appears in the master list, then
    /// captures a screenshot of the redesigned list row.
    @MainActor
    func testAddedHorseAppearsInList() throws {
        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
            for label in ["Allow", "OK", "Allow While Using App"] {
                if alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            }
            return false
        }
        app.launch()
        app.tap()

        let vet = app.textFields["Veterinarian Name"]
        XCTAssertTrue(vet.waitForExistence(timeout: 10))
        vet.tap(); vet.typeText("Dr. Test")
        let farm = app.textFields["Farm Name"]
        farm.tap(); farm.typeText("Test Farm")
        app.buttons["Start Assessment"].tap()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        if app.buttons["Show Sidebar"].exists {
            app.buttons["Show Sidebar"].tap()
        } else if app.buttons["Assessment"].exists {
            app.buttons["Assessment"].tap()
        }
        firstHittable(app, label: "Horses").tap()

        // Open the Add form (retry to clear the iPad-portrait panes overlay).
        let nameField = app.textFields["Horse name"]
        for _ in 0..<3 {
            if nameField.waitForExistence(timeout: 3) { break }
            if app.buttons["Add"].exists { app.buttons["Add"].tap() }
        }
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Add form did not open")

        // Fill in enough for a representative row.
        nameField.tap(); nameField.typeText("Thunder")
        let breed = app.textFields["Breed"]
        if breed.exists { breed.tap(); breed.typeText("Standardbred") }
        let color = app.textFields["Color"]
        if color.exists { color.tap(); color.typeText("Bay") }
        let sex = app.textFields["Sex"]
        if sex.exists { sex.tap(); sex.typeText("Stallion") }

        app.buttons["Save"].tap()

        // The new horse should now appear in the master list.
        XCTAssertTrue(app.staticTexts["Thunder"].waitForExistence(timeout: 10),
                      "Added horse did not appear in the list")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "horse-list-row"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Edits a horse, appends to its name, then taps Cancel — the change must be
    /// discarded (guards the working-copy behaviour behind the edit sheet).
    @MainActor
    func testEditHorseCancelDiscardsChanges() throws {
        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
            for label in ["Allow", "OK", "Allow While Using App"] {
                if alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            }
            return false
        }
        app.launch()
        app.tap()

        let vet = app.textFields["Veterinarian Name"]
        XCTAssertTrue(vet.waitForExistence(timeout: 10))
        vet.tap(); vet.typeText("Dr. Test")
        let farm = app.textFields["Farm Name"]
        farm.tap(); farm.typeText("Test Farm")
        app.buttons["Start Assessment"].tap()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        if app.buttons["Show Sidebar"].exists {
            app.buttons["Show Sidebar"].tap()
        } else if app.buttons["Assessment"].exists {
            app.buttons["Assessment"].tap()
        }
        firstHittable(app, label: "Horses").tap()

        // Add a horse named "Rowan".
        let nameField = app.textFields["Horse name"]
        for _ in 0..<3 {
            if nameField.waitForExistence(timeout: 3) { break }
            if app.buttons["Add"].exists { app.buttons["Add"].tap() }
        }
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Add form did not open")
        nameField.tap(); nameField.typeText("Rowan")
        app.buttons["Save"].tap()

        // The saved horse is auto-selected; its info view exposes an Edit button.
        XCTAssertTrue(app.staticTexts["Rowan"].waitForExistence(timeout: 10),
                      "Added horse did not appear")
        let editButton = app.buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10),
                      "Edit button not found in horse info")
        editButton.tap()

        // Edit sheet opens pre-filled; change the name, then Cancel.
        let editName = app.textFields["Horse name"]
        XCTAssertTrue(editName.waitForExistence(timeout: 5), "Edit sheet did not open")
        editName.tap(); editName.typeText("XYZ")

        app.buttons["Cancel"].tap()

        // Cancel must discard the edit: the list still shows the original name.
        XCTAssertTrue(app.staticTexts["Rowan"].waitForExistence(timeout: 5),
                      "Original horse name was lost after Cancel — edit was not discarded")
    }

    /// Returns the first hittable element matching `label`, trying buttons then
    /// static texts (List rows surface differently across layouts).
    @MainActor
    private func firstHittable(_ app: XCUIApplication, label: String) -> XCUIElement {
        let button = app.buttons[label]
        if button.exists { return button }
        return app.staticTexts[label]
    }
}
