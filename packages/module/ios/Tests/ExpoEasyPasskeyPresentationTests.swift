import XCTest
@testable import ExpoEasyPasskey

final class ExpoEasyPasskeyPresentationTests: XCTestCase {
  func testMissingViewControllerIsPresentationContextFailure() {
    XCTAssertThrowsError(try PasskeyPresentationAnchor.resolve(from: nil)) { error in
      guard let exception = error as? PasskeyMissingPresentationContextException else {
        XCTFail("Expected PasskeyMissingPresentationContextException, got \(error)")
        return
      }

      XCTAssertEqual(exception.code, "ERR_PASSKEY_PRESENTATION_CONTEXT")
    }
  }

  func testViewControllerWithoutWindowIsPresentationContextFailure() {
    let viewController = UIViewController()

    XCTAssertThrowsError(try PasskeyPresentationAnchor.resolve(from: viewController)) { error in
      guard let exception = error as? PasskeyMissingPresentationContextException else {
        XCTFail("Expected PasskeyMissingPresentationContextException, got \(error)")
        return
      }

      XCTAssertEqual(exception.code, "ERR_PASSKEY_PRESENTATION_CONTEXT")
    }
  }

  func testUsesViewControllerWindowWhenPresent() throws {
    let viewController = UIViewController()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    window.rootViewController = viewController
    window.makeKeyAndVisible()

    let anchor = try PasskeyPresentationAnchor.resolve(from: viewController)

    XCTAssertTrue(anchor === window)
  }
}
