import AuthenticationServices
import Foundation
import UIKit

/// Injectable Authorization Services facade for ceremony adapters.
/// Production uses `AuthenticationServicesController`; tests inject a fake.
protocol PasskeyPlatformControlling: AnyObject {
  var supportsExcludedCredentials: Bool { get }

  func perform(_ requests: [ASAuthorizationRequest]) async throws -> PasskeyPlatformCredential
}

enum PasskeyPlatformCredential {
  case registration(PasskeyRegistrationFields)
  case assertion(PasskeyAssertionFields)
  case unsupported
}

struct PasskeyRegistrationFields {
  let credentialID: Data
  let rawClientDataJSON: Data
  let rawAttestationObject: Data?
}

struct PasskeyAssertionFields {
  let credentialID: Data
  let rawClientDataJSON: Data
  let rawAuthenticatorData: Data
  let signature: Data
  let userID: Data?
}

final class AuthenticationServicesController: NSObject, PasskeyPlatformControlling {
  typealias PresentationAnchorProvider = () -> ASPresentationAnchor

  var supportsExcludedCredentials: Bool {
    if #available(iOS 17.4, *) {
      return true
    }

    return false
  }

  private let presentationAnchorProvider: PresentationAnchorProvider
  private var continuation: CheckedContinuation<PasskeyPlatformCredential, Error>?

  init(presentationAnchorProvider: @escaping PresentationAnchorProvider) {
    self.presentationAnchorProvider = presentationAnchorProvider
  }

  @MainActor
  func perform(_ requests: [ASAuthorizationRequest]) async throws -> PasskeyPlatformCredential {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      let controller = ASAuthorizationController(authorizationRequests: requests)
      controller.delegate = self
      controller.presentationContextProvider = self
      controller.performRequests()
    }
  }
}

extension AuthenticationServicesController: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    presentationAnchorProvider()
  }
}

extension AuthenticationServicesController: ASAuthorizationControllerDelegate {
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
      continuation?.resume(
        returning: .registration(
          PasskeyRegistrationFields(
            credentialID: credential.credentialID,
            rawClientDataJSON: credential.rawClientDataJSON,
            rawAttestationObject: credential.rawAttestationObject
          )
        )
      )
    } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
      continuation?.resume(
        returning: .assertion(
          PasskeyAssertionFields(
            credentialID: credential.credentialID,
            rawClientDataJSON: credential.rawClientDataJSON,
            rawAuthenticatorData: credential.rawAuthenticatorData,
            signature: credential.signature,
            userID: credential.userID
          )
        )
      )
    } else {
      continuation?.resume(returning: .unsupported)
    }

    continuation = nil
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
}

func mapAuthorizationError(_ error: Error) -> Error {
  if let authorizationError = error as? ASAuthorizationError {
    switch authorizationError.code {
    case .canceled:
      return PasskeyCanceledException()
    case .invalidResponse:
      return PasskeyInvalidCredentialException(error.localizedDescription)
    case .notHandled:
      return PasskeyNoCredentialException(error.localizedDescription)
    default:
      return PasskeyNativeException(error.localizedDescription)
    }
  }

  return PasskeyNativeException(error.localizedDescription)
}

func mapRegistrationFields(_ credential: PasskeyRegistrationFields) throws -> [String: Any] {
  let id = PasskeyEncoding.encodeBase64Url(credential.credentialID)
  guard let attestationObject = credential.rawAttestationObject,
        !attestationObject.isEmpty else {
    throw PasskeyNativeException("Registration response is missing an attestation object.")
  }

  return [
    "id": id,
    "rawId": id,
    "type": "public-key",
    "response": [
      "clientDataJSON": PasskeyEncoding.encodeBase64Url(credential.rawClientDataJSON),
      "attestationObject": PasskeyEncoding.encodeBase64Url(attestationObject)
    ],
    "clientExtensionResults": [:],
    "authenticatorAttachment": "platform"
  ]
}

func mapAssertionFields(_ credential: PasskeyAssertionFields) -> [String: Any] {
  let id = PasskeyEncoding.encodeBase64Url(credential.credentialID)
  var response: [String: Any] = [
    "clientDataJSON": PasskeyEncoding.encodeBase64Url(credential.rawClientDataJSON),
    "authenticatorData": PasskeyEncoding.encodeBase64Url(credential.rawAuthenticatorData),
    "signature": PasskeyEncoding.encodeBase64Url(credential.signature)
  ]

  if let userID = credential.userID {
    response["userHandle"] = PasskeyEncoding.encodeBase64Url(userID)
  } else {
    response["userHandle"] = NSNull()
  }

  return [
    "id": id,
    "rawId": id,
    "type": "public-key",
    "response": response,
    "clientExtensionResults": [:],
    "authenticatorAttachment": "platform"
  ]
}
