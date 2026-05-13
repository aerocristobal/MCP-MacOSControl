// STORY: STORY-013 — MCP Resources for Ambient Context
// COMPONENT: ResourceSubscriptionRegistry

import XCTest
@testable import MacOSControlLib

final class ResourceSubscriptionRegistryTests: XCTestCase {

    var observerLifecycle: MockWorkspaceObserverLifecycle!
    var dateProvider: MockDateProvider!
    var registry: ResourceSubscriptionRegistry!

    private let appUri = ResourceURIs.activeApplication

    override func setUp() {
        super.setUp()
        observerLifecycle = MockWorkspaceObserverLifecycle()
        dateProvider = MockDateProvider()
        registry = makeRegistry()
    }

    private func makeRegistry(debounce: TimeInterval = 0.0,
                              producer: @escaping () -> [String: Any]? = { ["name": "Safari"] }) -> ResourceSubscriptionRegistry {
        let r = ResourceSubscriptionRegistry(
            observerLifecycle: observerLifecycle,
            dateProvider: dateProvider,
            debounceInterval: debounce,
            publishQueue: DispatchQueue.main
        )
        r.registerContentProducer(appUri, producer)
        return r
    }

    // MARK: - Scenario 8 — concurrent subscribers receive identical content

    func test_publish_deliversIdenticalContent_toAllSubscribers() {
        var deliveriesA: [[String: Any]] = []
        var deliveriesB: [[String: Any]] = []
        registry.subscribe(appUri, clientId: "A") { deliveriesA.append($0) }
        registry.subscribe(appUri, clientId: "B") { deliveriesB.append($0) }

        registry.publish(uri: appUri, content: ["name": "Safari", "pid": 12345])

        XCTAssertEqual(deliveriesA.count, 1)
        XCTAssertEqual(deliveriesB.count, 1)
        XCTAssertEqual(deliveriesA[0]["name"] as? String, "Safari")
        XCTAssertEqual(deliveriesB[0]["name"] as? String, "Safari")
    }

    // MARK: - Scenarios 3 & 4 — app/window-switch update fires the subscriber

    func test_upstreamActivation_deliversUpdateToSubscribers() {
        var lastContent: [String: Any]?
        let expectation = expectation(description: "delivery after activation")
        registry = makeRegistry(debounce: 0.0, producer: {
            ["name": "Safari"]
        })
        registry.subscribe(appUri, clientId: "A") {
            lastContent = $0
            expectation.fulfill()
        }

        observerLifecycle.fireActivation()
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(lastContent?["name"] as? String, "Safari")
    }

    // MARK: - Scenario 7 — unsubscribe stops further deliveries

    func test_unsubscribe_stopsFurtherDeliveries() {
        var deliveries: [[String: Any]] = []
        registry.subscribe(appUri, clientId: "A") { deliveries.append($0) }

        registry.unsubscribe(appUri, clientId: "A")
        registry.publish(uri: appUri, content: ["name": "Safari"])

        XCTAssertEqual(deliveries.count, 0,
                       "Unsubscribed client must not receive further updates")
    }

    // MARK: - Scenario 7 — observer leak guard

    func test_subscribe_installsObserver_onFirstSubscriber() {
        XCTAssertEqual(observerLifecycle.activeObserverCount, 0)
        registry.subscribe(appUri, clientId: "A") { _ in }
        XCTAssertEqual(observerLifecycle.activeObserverCount, 1)
    }

    func test_subscribe_doesNotInstallExtraObserver_forSecondSubscriber() {
        registry.subscribe(appUri, clientId: "A") { _ in }
        registry.subscribe(appUri, clientId: "B") { _ in }
        XCTAssertEqual(observerLifecycle.activeObserverCount, 1,
                       "Multiple subscribers must share a single upstream NSWorkspace observer")
    }

    func test_unsubscribe_removesUnderlyingObserver_whenLastSubscriberLeaves() {
        registry.subscribe(appUri, clientId: "A") { _ in }
        XCTAssertEqual(observerLifecycle.activeObserverCount, 1)

        registry.unsubscribe(appUri, clientId: "A")

        XCTAssertEqual(observerLifecycle.activeObserverCount, 0,
                       "NSWorkspace observer must be removed when the last subscriber leaves to avoid leaks")
    }

    func test_unsubscribe_keepsObserver_whileOtherSubscribersRemain() {
        registry.subscribe(appUri, clientId: "A") { _ in }
        registry.subscribe(appUri, clientId: "B") { _ in }

        registry.unsubscribe(appUri, clientId: "A")

        XCTAssertEqual(observerLifecycle.activeObserverCount, 1,
                       "Observer must remain while other clients are still subscribed")
    }

    // MARK: - Per-URI signal source override (Scenario 4 plumbing)

    func test_registerSignalSource_routesURIToOverrideLifecycle() {
        let override = MockWorkspaceObserverLifecycle()
        let registry = makeRegistry()
        registry.registerSignalSource(appUri, override)

        registry.subscribe(appUri, clientId: "A") { _ in }

        XCTAssertEqual(override.activeObserverCount, 1,
                       "URI override must intercept the subscribe call")
        XCTAssertEqual(observerLifecycle.activeObserverCount, 0,
                       "Default lifecycle must NOT be touched when an override is registered")
    }

    func test_unsubscribeWithOverride_removesFromOverrideLifecycle() {
        let override = MockWorkspaceObserverLifecycle()
        let registry = makeRegistry()
        registry.registerSignalSource(appUri, override)
        registry.subscribe(appUri, clientId: "A") { _ in }
        XCTAssertEqual(override.activeObserverCount, 1)

        registry.unsubscribe(appUri, clientId: "A")

        XCTAssertEqual(override.activeObserverCount, 0,
                       "Token must be returned to the override lifecycle, not the default")
    }

    func test_eventOnOverrideLifecycle_deliversToSubscribers() {
        let override = MockWorkspaceObserverLifecycle()
        let registry = makeRegistry(debounce: 0.0)
        registry.registerSignalSource(appUri, override)

        let expectation = expectation(description: "override-routed delivery")
        registry.subscribe(appUri, clientId: "A") { _ in expectation.fulfill() }

        override.fireActivation()

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Debounce coalescing

    func test_rapidActivations_coalesce_toSingleDelivery() {
        var deliveryCount = 0
        let registry = makeRegistry(debounce: 0.1)
        registry.subscribe(appUri, clientId: "A") { _ in deliveryCount += 1 }

        let expectation = expectation(description: "single coalesced delivery")
        let observer = observerLifecycle!

        DispatchQueue.main.async {
            observer.fireActivation()
            observer.fireActivation()
            observer.fireActivation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(deliveryCount, 1,
                       "Three rapid activations within debounce window must coalesce to a single delivery")
    }
}
