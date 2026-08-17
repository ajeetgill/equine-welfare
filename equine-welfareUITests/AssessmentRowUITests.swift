//
//  AssessmentRowUITests.swift
//  equine-welfareUITests
//
//  Visual tests for the previous-assessment row — the surface refactored in
//  the god-file split. Drives the real app in the simulator through the row's
//  entire surface (home row, preview sheet, sign-in sheet, delete
//  confirmation) and captures a named screenshot at every stop, so a visual
//  diff of the flow lives in each test run's .xcresult bundle.
//
//  Launch arguments (handled in equine_welfareApp.init) make the run
//  deterministic: auth is reset so Sync always prompts for sign-in, and
//  assessments are wiped so exactly one row exists.
//

import XCTest

final class AssessmentRowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAssessmentRowVisualFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset-auth", "--uitest-wipe-data"]
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

        // Create one assessment, then come straight back home.
        let vet = app.textFields["Veterinarian Name"]
        XCTAssertTrue(vet.waitForExistence(timeout: 10), "Vet name field missing")
        vet.tap(); vet.typeText("Dr. Visual")
        let farm = app.textFields["Farm Name"]
        farm.tap(); farm.typeText("Snapshot Farm")
        app.buttons["Start Assessment"].tap()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                      "Workspace did not present")

        // "Done" sits in the split view's sidebar, which several iPad
        // presentations hide by default — reveal it first (same dance as
        // NavigationFlowUITests).
        let done = app.buttons["Done"].firstMatch
        if !done.waitForExistence(timeout: 5) {
            if app.buttons["Show Sidebar"].exists {
                app.buttons["Show Sidebar"].tap()
            } else if app.buttons["Assessment"].exists {
                app.buttons["Assessment"].tap()
            }
        }
        XCTAssertTrue(done.waitForExistence(timeout: 10), "Workspace Done button missing")
        done.tap()

        // Home shows the single row (displayName is date-vet-farm, dashed).
        let row = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Dr.-Visual-Snapshot-Farm'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10),
                      "Previous-assessment row did not appear on home")
        snapshot(app, name: "01-home-with-row")

        // Preview sheet: the RTF-matching report, dismissed with Done.
        let preview = app.buttons["assessmentRow.preview"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "Preview button missing")
        preview.tap()
        let previewDone = app.buttons["Done"].firstMatch
        XCTAssertTrue(previewDone.waitForExistence(timeout: 10), "Preview sheet did not open")
        snapshot(app, name: "02-assessment-preview")
        previewDone.tap()

        // Sync while signed out: must prompt with the sign-in sheet, not fail.
        let sync = app.buttons["assessmentRow.sync"].firstMatch
        XCTAssertTrue(sync.waitForExistence(timeout: 5), "Sync button missing")
        sync.tap()
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 10),
                      "Sign-in sheet did not appear for signed-out sync")
        XCTAssertTrue(app.textFields["Email"].exists, "Email field missing on sign-in sheet")
        XCTAssertTrue(app.secureTextFields["Password"].exists, "Password field missing on sign-in sheet")
        snapshot(app, name: "03-sign-in-sheet")
        app.buttons["Cancel"].tap()

        // Delete: confirmation dialog first, row gone after confirming.
        let delete = app.buttons["assessmentRow.delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Delete button missing")
        delete.tap()
        let confirmDelete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 10),
                      "Delete confirmation did not appear")
        snapshot(app, name: "04-delete-confirmation")
        confirmDelete.tap()

        let gone = row.waitForNonExistence(timeout: 10)
        XCTAssertTrue(gone, "Row still present after delete")
        snapshot(app, name: "05-home-after-delete")
    }

    /// Attaches a full-screen screenshot that survives in the .xcresult bundle
    /// (open it in Xcode to review the visuals of the whole flow).
    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
