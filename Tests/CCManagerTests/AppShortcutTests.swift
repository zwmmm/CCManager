import XCTest
@testable import CCManager

final class AppShortcutTests: XCTestCase {
    func testDefaultShortcutsIncludeCommonProviderActions() {
        let shortcuts = AppShortcut.defaultShortcuts
        let labelsByTitle = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.title, $0.displayLabel) })

        XCTAssertEqual(labelsByTitle["New Provider"], "⌘T")
        XCTAssertEqual(labelsByTitle["Edit Selected"], "⌘E")
        XCTAssertEqual(labelsByTitle["Apply Selected"], "⌘↩")
        XCTAssertEqual(labelsByTitle["Settings"], "⌘,")
        XCTAssertEqual(labelsByTitle["Close Window"], "⌘W")
    }
}
