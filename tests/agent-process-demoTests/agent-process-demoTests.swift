import XCTest
@testable import agent-process-demo

final class agent-process-demoTests: XCTestCase {
    func testHello() {
        XCTAssertEqual(agent-process-demo().hello(), "Hello, agent-process-demo!")
    }
}
