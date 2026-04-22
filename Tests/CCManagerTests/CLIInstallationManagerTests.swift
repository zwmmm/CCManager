import XCTest
@testable import CCManager

final class CLIInstallationManagerTests: XCTestCase {
    func testResolvesInstalledCLIFromTargetPathWhenPathLookupMissesIt() {
        let installedPath = CLIInstallationManager.resolveInstalledCLIPath(
            whichPath: nil,
            targetPath: "/usr/local/bin/ccmanager",
            fileExists: { path in path == "/usr/local/bin/ccmanager" }
        )

        XCTAssertEqual(installedPath, "/usr/local/bin/ccmanager")
    }
}
