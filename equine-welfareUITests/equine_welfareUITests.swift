import XCTest

final class equine_welfareUITests: XCTestCase {

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
    
    @MainActor
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
        
        app.scrollViews.otherElements.scrollViews.children(matching: .other).element(boundBy: 0).children(matching: .other).element.children(matching: .button).element(boundBy: 2).tap()
        app.popovers.sheets["Delete Assessment"].scrollViews.otherElements.buttons["Delete"].tap()
        
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
        
        app.navigationBars["Select Sections"]/*@START_MENU_TOKEN@*/.buttons["ToggleSidebar"]/*[[".buttons[\"Show Sidebar\"]",".buttons[\"ToggleSidebar\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        let elementsQuery = elementsQuery2
        elementsQuery/*@START_MENU_TOKEN@*/.staticTexts["Overview"]/*[[".buttons[\"Overview\"].staticTexts[\"Overview\"]",".staticTexts[\"Overview\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        let popoverdismissregionElement = app/*@START_MENU_TOKEN@*/.otherElements["PopoverDismissRegion"]/*[[".otherElements[\"dismiss popup\"]",".otherElements[\"PopoverDismissRegion\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        popoverdismissregionElement.tap()
        app.navigationBars["Overview"]/*@START_MENU_TOKEN@*/.buttons["ToggleSidebar"]/*[[".buttons[\"Show Sidebar\"]",".buttons[\"ToggleSidebar\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        elementsQuery/*@START_MENU_TOKEN@*/.staticTexts["Horses"]/*[[".buttons[\"Horses\"].staticTexts[\"Horses\"]",".staticTexts[\"Horses\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        popoverdismissregionElement.tap()
        app.navigationBars["All Horses"]/*@START_MENU_TOKEN@*/.staticTexts["Add"]/*[[".otherElements[\"Add\"]",".buttons[\"Add\"].staticTexts[\"Add\"]",".staticTexts[\"Add\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        elementsQuery2.sliders["4"].swipeRight()
                
        app.navigationBars["Add Horse"]/*@START_MENU_TOKEN@*/.buttons["ToggleSidebar"]/*[[".buttons[\"Show Sidebar\"]",".buttons[\"ToggleSidebar\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        elementsQuery/*@START_MENU_TOKEN@*/.staticTexts["Gallery"]/*[[".buttons[\"Gallery\"].staticTexts[\"Gallery\"]",".staticTexts[\"Gallery\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        popoverdismissregionElement.tap()
        
        app.navigationBars["Assessment Sections Gallery"]/*@START_MENU_TOKEN@*/.buttons["ToggleSidebar"]/*[[".buttons[\"Show Sidebar\"]",".buttons[\"ToggleSidebar\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        elementsQuery/*@START_MENU_TOKEN@*/.staticTexts["Side Notes"]/*[[".buttons[\"Side Notes\"].staticTexts[\"Side Notes\"]",".staticTexts[\"Side Notes\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app/*@START_MENU_TOKEN@*/.otherElements["PopoverDismissRegion"]/*[[".otherElements[\"dismiss popup\"]",".otherElements[\"PopoverDismissRegion\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        elementsQuery.staticTexts["Tap to add notes..."].tap()
        
        let togglesidebarButton = app.navigationBars["Select Sections"]/*@START_MENU_TOKEN@*/.buttons["ToggleSidebar"]/*[[".buttons[\"Show Sidebar\"]",".buttons[\"ToggleSidebar\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/

        app.navigationBars["Side Notes"]/*@START_MENU_TOKEN@*/.buttons["ToggleSidebar"]/*[[".buttons[\"Show Sidebar\"]",".buttons[\"ToggleSidebar\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        elementsQuery/*@START_MENU_TOKEN@*/.staticTexts["Section Selection"]/*[[".buttons[\"Section Selection\"].staticTexts[\"Section Selection\"]",".staticTexts[\"Section Selection\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        popoverdismissregionElement.tap()
        scrollViewsQuery.otherElements.containing(.button, identifier:"info.circle").children(matching: .switch).matching(identifier: "Close").element(boundBy: 0).tap()
        togglesidebarButton.tap()
    
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
       

        app.navigationBars["Add Horse"].buttons["ToggleSidebar"].tap()

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
}
