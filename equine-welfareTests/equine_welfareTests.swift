import Testing
import XCTest
@testable import Horse_App

struct Horse_AppTests {
    // unit testing to check that the functions work correct, still incorrect
    func testAddingHorse() {
        let initialCount = horseData.horses.count
        horseData.addHorse(name: "Test Horse", breed: "Test Breed", time: 4)

        XCTAssertEqual(horseData.horses.count, initialCount + 1, "Horse should be added to the list")
        XCTAssertEqual(horseData.horses.last?.name, "Test Horse", "Horse name should match")
        }

    func testDeletingHorse() {
        horseData.addHorse(name: "Test Horse", breed: "Test Breed", time: 4)
        let initialCount = horseData.horses.count

        horseData.deleteHorse(at: IndexSet(integer: initialCount - 1))

        XCTAssertEqual(horseData.horses.count, initialCount - 1, "Horse should be deleted")
        }

}
