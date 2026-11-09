import XCTest

/// Reproduces Jason's 2026-11-09 freeze: browsing the map in the boat (zoom in
/// and out, tap around, set the spot, zoom, back to the whole state) until the
/// app stopped taking input. Every round ends with a responsiveness probe; a
/// hung main thread makes the query time out and the test fail at that round.
final class MapStressTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testMapSurvivesBrowsing() {
        let app = XCUIApplication()
        app.launchArguments = ["-store", "-place", "Horicon", "-rules", "waterfowl", "-scroll", "daybar"]
        app.launch()
        let map = app.descendants(matching: .any)["zonemap"]
        XCTAssertTrue(map.waitForExistence(timeout: 10), "map not found")

        /// Scroll the page (dragging outside the map) until the whole map is on screen.
        func bringMapIntoView() {
            for _ in 0..<8 {
                let f = map.frame, h = app.frame.height
                if f.minY > 90 && f.maxY < h - 60 { return }
                let up = f.minY <= 90   // map too high: drag the page down
                let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: up ? 0.2 : 0.8))
                from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: up ? 0.5 : 0.5)))
            }
        }

        for round in 1...10 {
            bringMapIntoView()
            map.pinch(withScale: 3.0, velocity: 3.0)            // zoom in
            map.swipeLeft(); map.swipeDown()                    // pan around (zoomed)
            map.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45)).tap()   // read a spot
            let use = app.buttons["Use this spot"]
            if use.waitForExistence(timeout: 2) { use.tap() }   // set location from the map
            map.doubleTap()                                     // zoom in more
            map.pinch(withScale: 0.25, velocity: -3.0)          // zoom back out
            if app.buttons["Whole state"].exists { app.buttons["Whole state"].tap() }   // whole state
            if !app.buttons["Zoom in"].exists {
                print("TREE-BEGIN round \(round)\n" + app.debugDescription + "\nTREE-END")
                let a = XCTAttachment(screenshot: app.screenshot()); a.lifetime = .keepAlways; add(a)
                try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/claude-501/maptest-fail.png"))
            }
            app.buttons["Zoom in"].tap()
            app.buttons["Center on your spot"].tap()
            map.pinch(withScale: 0.4, velocity: -2.0)
            map.swipeRight()
            bringMapIntoView()

            if round % 3 == 0 {                                 // set location from the sheet
                app.buttons["spotButton"].tap()
                let cell = app.buttons["Madison"]
                if cell.waitForExistence(timeout: 3) { cell.tap() } else { app.buttons["Done"].tap() }
            }

            bringMapIntoView()
            // probe: the app must still answer, promptly
            let duck = app.buttons["Duck zones"]
            XCTAssertTrue(duck.waitForExistence(timeout: 5), "round \(round): app stopped answering")
            duck.tap()
            app.buttons["Hours zones"].tap()
        }
    }
}
