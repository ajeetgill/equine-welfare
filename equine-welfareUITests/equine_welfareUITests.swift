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

    override func tearDownWithError() throws {
        
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
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 0)/*@START_MENU_TOKEN@*/.images["xmark"]/*[[".images[\"Close\"]",".images[\"xmark\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
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
    func testFullUi() throws {
        
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
        infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close").element(boundBy: 0).tap()
        
        let elementsQuery2 = scrollViewsQuery.otherElements
        let selectedSwitch = elementsQuery2.switches["Selected"]
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
    
    @MainActor
    func testFullUiRandom() throws {
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
        
        let selectedSwitch = scrollViewsQuery.otherElements.switches["Selected"]
        let closeSwitches = infoCircleElementsQuery.children(matching: .switch).matching(identifier: "Close")
        let switchCount = closeSwitches.count
        let shuffledSwitchIndexes = Array(0..<switchCount).shuffled()
        
        for i in shuffledSwitchIndexes {
            closeSwitches.element(boundBy: i).tap()
            selectedSwitch.tap()
        }

        app.navigationBars["Select Sections"].buttons["ToggleSidebar"].tap()

        let elementsQuery = scrollViewsQuery.otherElements
        elementsQuery.staticTexts["Overview"].tap()

        let popoverdismissregionElement = app.otherElements["PopoverDismissRegion"]
        popoverdismissregionElement.tap()
        app.navigationBars["Overview"].buttons["ToggleSidebar"].tap()

        elementsQuery.staticTexts["Horses"].tap()
        popoverdismissregionElement.tap()
        app.navigationBars["All Horses"].staticTexts["Add"].tap()

        elementsQuery.sliders["4"].swipeRight()
       

        app.navigationBars["Add Horse"].buttons["Cancel"].tap()
        app.navigationBars["All Horses"].buttons["ToggleSidebar"].tap()

        elementsQuery.staticTexts["Gallery"].tap()
        popoverdismissregionElement.tap()
        app.navigationBars["Assessment Sections Gallery"].buttons["ToggleSidebar"].tap()

        elementsQuery.staticTexts["Side Notes"].tap()
        app.otherElements["PopoverDismissRegion"].tap()
        elementsQuery.staticTexts["Tap to add notes..."].tap()

        let togglesidebarButton = app.navigationBars["Select Sections"].buttons["ToggleSidebar"]
        app.navigationBars["Side Notes"].buttons["ToggleSidebar"].tap()
        elementsQuery.staticTexts["Section Selection"].tap()
        popoverdismissregionElement.tap()
        
        scrollViewsQuery.otherElements.containing(.button, identifier:"info.circle").children(matching: .switch).matching(identifier: "Close").element(boundBy: 0).tap()
        togglesidebarButton.tap()
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
