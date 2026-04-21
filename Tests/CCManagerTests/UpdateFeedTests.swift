import XCTest
@testable import CCManager

final class UpdateFeedTests: XCTestCase {
    func testParsesFlowStyleAppcastEnclosure() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
            <channel>
                <item>
                    <title>CCManager 1.9.0</title>
                    <description><![CDATA[
                        <h2>更新内容</h2>
                        <p>改用内置热更新</p>
                    ]]></description>
                    <pubDate>Tue, 21 Apr 2026 12:00:00 +0800</pubDate>
                    <enclosure
                        url="https://github.com/zwmmm/CCManager/releases/download/v1.9.0/CCManager.app.zip"
                        sparkle:version="25"
                        sparkle:shortVersionString="1.9.0"
                        sparkle:sha256="0123456789abcdef"
                        length="12345"
                        type="application/octet-stream"
                    />
                    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
                </item>
            </channel>
        </rss>
        """

        let item = try UpdateFeedParser.parse(xml)

        XCTAssertEqual(item.version, "25")
        XCTAssertEqual(item.shortVersion, "1.9.0")
        XCTAssertEqual(item.sha256, "0123456789abcdef")
        XCTAssertEqual(item.downloadURL.absoluteString, "https://github.com/zwmmm/CCManager/releases/download/v1.9.0/CCManager.app.zip")
        XCTAssertEqual(item.minimumSystemVersion, "13.0")
        XCTAssertEqual(item.releaseNotes, "## 更新内容\n改用内置热更新")
    }

    func testVersionComparisonUsesNumericOrdering() {
        XCTAssertTrue(UpdateFeedParser.isVersion("1.10.0", newerThan: "1.9.9"))
        XCTAssertFalse(UpdateFeedParser.isVersion("1.8.0", newerThan: "1.9.0"))
        XCTAssertFalse(UpdateFeedParser.isVersion("1.9.0", newerThan: "1.9.0"))
    }
}
