import AuthenticationServices
import UIKit

enum PasskeyPresentationAnchor {
  static func resolve(from viewController: UIViewController?) throws -> ASPresentationAnchor {
    guard let viewController else {
      throw PasskeyMissingPresentationContextException()
    }

    guard let window = viewController.view.window else {
      throw PasskeyMissingPresentationContextException()
    }

    return window
  }
}
