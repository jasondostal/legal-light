import XCTest

/// Jason, 2026-11-09: zoomed in on the east coast, set his spot by GPS from the
/// sheet, came back to the map: it hadn't moved, and the arrow / double-arrow
/// buttons "did nothing".
final class MapButtonTests: XCTestCase {
    func testButtonsAfterChangingSpot() {
        let app = XCUIApplication()
        app.launchArguments = ["-store", "-place", "Sheboygan", "-rules", "waterfowl", "-scroll", "daybar"]
        app.launch()
        let map = app.descendants(matching: .any)["zonemap"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        func z() -> String { app.descendants(matching: .any)["mapzoom"].value as? String ?? "?" }
        map.pinch(withScale: 4.0, velocity: 3.0)
        print("STEP zoomed in on the east: \(z())")
        // change the spot from the sheet (stands in for "Use my location")
        app.buttons["spotButton"].tap()
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 3) { search.tap(); search.typeText("Wausau") }
        let wausau = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Wausau'")).firstMatch
        XCTAssertTrue(wausau.waitForExistence(timeout: 3)); wausau.tap()
        sleep(1)
        print("STEP after changing spot: \(z())")
        let zoomed = Double(z().split(separator: " ").last ?? "0") ?? 0
        XCTAssertGreaterThan(zoomed, 1.01, "still zoomed after the spot change")
        let whole = app.buttons["Whole state"]
        print("STEP whole-state button exists=\(whole.exists) hittable=\(whole.exists && whole.isHittable)")
        if whole.exists { whole.tap() }
        sleep(1); print("STEP after Whole state tap: \(z())")
        XCTAssertEqual(z(), "zoom 1.00", "Whole state button must reset the zoom")
        let center = app.buttons["Center on your spot"]
        print("STEP center button exists=\(center.exists) hittable=\(center.exists && center.isHittable)")
        if center.exists { center.tap() }
        sleep(1); print("STEP after Center tap: \(z())")
        XCTAssertEqual(z(), "zoom 4.00", "Center button must zoom to the spot")
        app.buttons["Zoom in"].tap(); sleep(1); print("STEP after Zoom in: \(z())")
        XCTAssertEqual(z(), "zoom 7.20")
        app.buttons["Zoom out"].tap(); sleep(1); print("STEP after Zoom out: \(z())")
        XCTAssertEqual(z(), "zoom 4.00")
        let shot = app.screenshot(); try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/claude-501/mapbuttons.png"))
    }
}
