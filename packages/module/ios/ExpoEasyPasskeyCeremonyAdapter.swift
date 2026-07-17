import AuthenticationServices
import ExpoModulesCore
import Foundation
import UIKit

final class ExpoEasyPasskeyCeremonyAdapter: NSObject {
  typealias PresentationAnchorProvider = () -> ASPresentationAnchor

  static var isSupported: Bool {
    if #available(iOS 16.0, *) {
      return true
    }

    return false
  }

  private let presentationAnchorProvider: PresentationAnchorProvider
  private var continuation: CheckedContinuation<[String: Any], Error>?

  init(presentationAnchorProvider: @escaping PresentationAnchorProvider) {
    self.presentationAnchorProvider = presentationAnchorProvider
  }

  func create(
    _ request: PasskeyCreateRequest,
    policy: PasskeyRegistrationPolicy.Resolved
  ) async throws -> [String: Any] {
    guard Self.isSupported else {
      throw PasskeyUnsupportedException()
    }

    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
      relyingPartyIdentifier: request.rpId
    )
    let registrationRequest = provider.createCredentialRegistrationRequest(
      challenge: request.challengeData,
      name: request.userName,
      userID: request.userIdData
    )

    registrationRequest.displayName = request.userDisplayName
    registrationRequest.attestationPreference = policy.attestationPreference
    applyUserVerification(request.userVerification, to: registrationRequest)
    try applyExcludedCredentials(request.excludeCredentials, to: registrationRequest)

    return try await perform([registrationRequest])
  }

  func get(_ request: PasskeyGetRequest) async throws -> [String: Any] {
    guard Self.isSupported else {
      throw PasskeyUnsupportedException()
    }

    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
      relyingPartyIdentifier: request.rpId
    )
    let assertionRequest = provider.createCredentialAssertionRequest(
      challenge: request.challengeData
    )

    applyAllowedCredentials(request.allowCredentials, to: assertionRequest)
    applyUserVerification(request.userVerification, to: assertionRequest)

    return try await perform([assertionRequest])
  }

  @MainActor
  private func perform(_ requests: [ASAuthorizationRequest]) async throws -> [String: Any] {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      let controller = ASAuthorizationController(authorizationRequests: requests)
      controller.delegate = self
      controller.presentationContextProvider = self
      controller.performRequests()
    }
  }

  private func applyUserVerification(
    _ userVerification: String?,
    to request: ASAuthorizationPublicKeyCredentialRegistrationRequest
  ) {
    guard let preference = userVerificationPreference(userVerification) else {
      return
    }

    request.userVerificationPreference = preference
  }

  private func applyAllowedCredentials(
    _ credentials: [PasskeyCredentialDescriptor],
    to request: ASAuthorizationPlatformPublicKeyCredentialAssertionRequest
  ) {
    guard !credentials.isEmpty else {
      return
    }

    request.allowedCredentials = credentials.map(platformCredentialDescriptor)
  }

  private func applyExcludedCredentials(
    _ credentials: [PasskeyCredentialDescriptor],
    to request: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest
  ) throws {
    guard !credentials.isEmpty else {
      return
    }

    guard #available(iOS 17.4, *) else {
      throw PasskeyValidationException("excludeCredentials requires iOS 17.4 or newer")
    }

    request.excludedCredentials = credentials.map(platformCredentialDescriptor)
  }

  private func platformCredentialDescriptor(
    _ credential: PasskeyCredentialDescriptor
  ) -> ASAuthorizationPlatformPublicKeyCredentialDescriptor {
    ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: credential.idData)
  }

  private func applyUserVerification(
    _ userVerification: String?,
    to request: ASAuthorizationPublicKeyCredentialAssertionRequest
  ) {
    guard let preference = userVerificationPreference(userVerification) else {
      return
    }

    request.userVerificationPreference = preference
  }

  private func userVerificationPreference(
    _ userVerification: String?
  ) -> ASAuthorizationPublicKeyCredentialUserVerificationPreference? {
    switch userVerification {
    case "required":
      return .required
    case "discouraged":
      return .discouraged
    case "preferred", nil:
      return .preferred
    default:
      return nil
    }
  }
}

extension ExpoEasyPasskeyCeremonyAdapter: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    presentationAnchorProvider()
  }
}

extension ExpoEasyPasskeyCeremonyAdapter: ASAuthorizationControllerDelegate {
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    do {
      if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
        continuation?.resume(returning: try mapRegistrationCredential(credential))
      } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
        continuation?.resume(returning: mapAssertionCredential(credential))
      } else {
        continuation?.resume(throwing: PasskeyNativeException("Unsupported authorization credential response."))
      }
    } catch {
      continuation?.resume(throwing: error)
    }

    continuation = nil
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    if let authorizationError = error as? ASAuthorizationError {
      switch authorizationError.code {
      case .canceled:
        continuation?.resume(throwing: PasskeyCanceledException())
      case .invalidResponse:
        continuation?.resume(
          throwing: PasskeyInvalidCredentialException(error.localizedDescription)
        )
      case .notHandled:
        continuation?.resume(
          throwing: PasskeyNoCredentialException(error.localizedDescription)
        )
      default:
        continuation?.resume(throwing: PasskeyNativeException(error.localizedDescription))
      }
    } else {
      continuation?.resume(throwing: PasskeyNativeException(error.localizedDescription))
    }

    continuation = nil
  }
}

private func mapRegistrationCredential(
  _ credential: ASAuthorizationPlatformPublicKeyCredentialRegistration
) throws -> [String: Any] {
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

private func mapAssertionCredential(
  _ credential: ASAuthorizationPlatformPublicKeyCredentialAssertion
) -> [String: Any] {
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
