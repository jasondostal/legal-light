import XCTest

/// One action at a time, logging the map's zoom after each, to find the step
/// after which gestures stop landing.
final class MapStepTests: XCTestCase {
    func testStepByStep() {
        let app = XCUIApplication()
        app.launchArguments = ["-store", "-place", "Horicon", "-rules", "waterfowl", "-scroll", "daybar"]
        app.launch()
        let map = app.descendants(matching: .any)["zonemap"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        func log(_ step: String) { print("STEP \(step): \(app.descendants(matching: .any)["mapzoom"].value as? String ?? "?") buttons=\(map.buttons.count)") }
        log("start")
        map.pinch(withScale: 3.0, velocity: 3.0); log("pinch in")
        map.pinch(withScale: 0.3, velocity: -3.0); log("pinch out")
        map.pinch(withScale: 3.0, velocity: 3.0); log("pinch in again")
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45)).tap(); log("tap spot")
        map.pinch(withScale: 0.5, velocity: -3.0); log("pinch out after tap (pick showing)")
        map.pinch(withScale: 2.0, velocity: 3.0); log("pinch in")
        let use = app.buttons["Use this spot"]
        if use.waitForExistence(timeout: 2) { use.tap(); log("use this spot") } else { log("no use button") }
        map.pinch(withScale: 0.3, velocity: -3.0); log("pinch out after use")
        map.pinch(withScale: 3.0, velocity: 3.0); log("pinch in after use")
        map.doubleTap(); log("double tap")
        map.swipeLeft(); log("swipe")
        map.pinch(withScale: 0.3, velocity: -3.0); log("pinch out")
    }
}
