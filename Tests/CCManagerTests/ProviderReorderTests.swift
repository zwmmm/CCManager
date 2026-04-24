import XCTest
@testable import CCManager

final class ProviderReorderTests: XCTestCase {
    func testMovingProviderBeforeAnotherProviderRenumbersFlatOrder() {
        let providers = [
            makeProvider("A", sortOrder: 0),
            makeProvider("B", sortOrder: 1),
            makeProvider("C", sortOrder: 2),
            makeProvider("D", sortOrder: 3),
        ]

        let reordered = ProviderStore.providers(
            providers,
            moving: providers[0].id,
            to: providers[2].id,
            inGroup: nil
        )

        XCTAssertEqual(reordered.map(\.name), ["B", "C", "A", "D"])
        XCTAssertEqual(reordered.map(\.sortOrder), [0, 1, 2, 3])
    }

    func testMovingProviderWithinGroupOnlyRenumbersThatGroup() {
        let claudeA = makeProvider("Claude A", type: .claudeCode, sortOrder: 0)
        let codexA = makeProvider("Codex A", type: .codex, sortOrder: 0)
        let claudeB = makeProvider("Claude B", type: .claudeCode, sortOrder: 1)
        let codexB = makeProvider("Codex B", type: .codexOAuth, sortOrder: 1)
        let providers = [claudeA, codexA, claudeB, codexB]

        let reordered = ProviderStore.providers(
            providers,
            moving: claudeA.id,
            to: claudeB.id,
            inGroup: .claudeCode
        )

        XCTAssertEqual(reordered.filter { $0.type == .claudeCode }.map(\.name), ["Claude B", "Claude A"])
        XCTAssertEqual(reordered.first { $0.id == codexA.id }?.sortOrder, 0)
        XCTAssertEqual(reordered.first { $0.id == codexB.id }?.sortOrder, 1)
    }

    func testCannotMoveProviderAcrossGroups() {
        let claude = makeProvider("Claude", type: .claudeCode, sortOrder: 0)
        let codex = makeProvider("Codex", type: .codex, sortOrder: 0)

        let reordered = ProviderStore.providers(
            [claude, codex],
            moving: claude.id,
            to: codex.id,
            inGroup: .claudeCode
        )

        XCTAssertEqual(reordered, [claude, codex])
    }

    func testChangedSortOrderProvidersOnlyIncludesRenumberedProviders() {
        let providers = [
            makeProvider("A", sortOrder: 0),
            makeProvider("B", sortOrder: 1),
            makeProvider("C", sortOrder: 2),
        ]

        let reordered = ProviderStore.providers(
            providers,
            moving: providers[0].id,
            to: providers[1].id,
            inGroup: nil
        )

        let changedProviders = ProviderStore.providersWithChangedSortOrder(
            from: providers,
            to: reordered
        )

        XCTAssertEqual(changedProviders.map(\.name), ["B", "A"])
    }

    private func makeProvider(
        _ name: String,
        type: ProviderType = .claudeCode,
        sortOrder: Int
    ) -> Provider {
        Provider(
            name: name,
            type: type,
            apiKey: "key",
            baseUrl: "https://example.com",
            sortOrder: sortOrder
        )
    }
}
