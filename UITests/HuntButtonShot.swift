import XCTest

/// Screenshot aid: the header (gear) and the hunt button before and after starting.
final class HuntButtonShot: XCTestCase {
    func testHuntButtonStates() {
        let app = XCUIApplication()
        app.launchArguments = ["-store", "-place", "Stevens Point", "-rules", "waterfowl"]
        app.launch()
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Start hunt'")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/claude-501/hunt-before.png"))
        start.tap()
        let end = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'End hunt'")).firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        print("STEP running label: \(end.label)")
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/claude-501/hunt-after.png"))
        XCTAssertTrue(app.buttons["Settings"].isHittable)
        end.tap()
    }
}
