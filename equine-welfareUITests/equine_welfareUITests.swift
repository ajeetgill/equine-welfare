//
//  equine_welfareUITests.swift
//  equine-welfareUITests
//
//  Created by Ajeet Gill on 19/02/25.
//

import XCTest

final class equine_welfareUITests: XCTestCase {

    override func setUpWithError() throws {

        continueAfterFailure = false


    }

    @MainActor
    func testStartAssesment() throws {
        let app = XCUIApplication()
        app.launch()

        let vetName = app.textFields["Veterinarian Name"]
        vetName.tap()
        vetName.typeText("Test Name")

        let farmName = app.textFields["Farm Name"]
        farmName.tap()
        farmName.typeText("Test Farm")

        let button = app.buttons["Start Assessment"]
        XCTAssertTrue(button.exists)

        button.tap()

    }

    func testSections() throws {
        let app = XCUIApplication()
        app.launch()

        let vetName = app.textFields["Veterinarian Name"]
        vetName.tap()
        vetName.typeText("Test Name")

        let farmName = app.textFields["Farm Name"]
        farmName.tap()
        farmName.typeText("Test Farm")

        let button = app.buttons["Start Assessment"]
        XCTAssertTrue(button.exists)

        button.tap()


        let scrollViewsQuery = app.scrollViews
        let infoCircleElementsQuery = scrollViewsQuery.otherElements.containing(.button, identifier:"info.circle")
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 0).images["xmark"].tap()

        let selectedSwitch = scrollViewsQuery.otherElements.switches["Selected"]
        selectedSwitch.tap()
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 1).tap()
        selectedSwitch.tap()
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 2).tap()
        selectedSwitch.tap()
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 3).tap()
        selectedSwitch.tap()
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 4).tap()
        selectedSwitch.tap()
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 5).tap()
        selectedSwitch.tap()
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 6).tap()
        selectedSwitch.tap()
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 7).tap()
        selectedSwitch.tap()
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 8).tap()
        selectedSwitch.tap()
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 9).tap()
        selectedSwitch.tap()

    }


    func testDeleteAssessment() throws {
        let app = XCUIApplication()
        app.launch()

        let deleteStaticText = app.scrollViews.otherElements.scrollViews.children(matching: .other).element(boundBy: 0).children(matching: .other).element.children(matching: .button).matching(identifier: "Delete").element(boundBy: 0).staticTexts["Delete"]
        deleteStaticText.tap()

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
}