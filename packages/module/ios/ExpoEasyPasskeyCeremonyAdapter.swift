import AuthenticationServices
import Foundation

final class ExpoEasyPasskeyCeremonyAdapter {
  static var isSupported: Bool {
    if #available(iOS 16.0, *) {
      return true
    }

    return false
  }

  private let platformController: PasskeyPlatformControlling

  init(platformController: PasskeyPlatformControlling) {
    self.platformController = platformController
  }

  init(presentationAnchorProvider: @escaping AuthenticationServicesController.PresentationAnchorProvider) {
    self.platformController = AuthenticationServicesController(
      presentationAnchorProvider: presentationAnchorProvider
    )
  }

  func create(
    _ request: PasskeyCreateRequest,
    policy: PasskeyRegistrationPolicy.AttestationPreference
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
    registrationRequest.attestationPreference = policy.kind
    applyUserVerification(request.userVerification, to: registrationRequest)
    try applyExcludedCredentials(request.excludeCredentials, to: registrationRequest)

    return try await complete(registrationRequest)
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

    return try await complete(assertionRequest)
  }

  private func complete(_ request: ASAuthorizationRequest) async throws -> [String: Any] {
    do {
      switch try await platformController.perform([request]) {
      case let .registration(fields):
        return try mapRegistrationFields(fields)
      case let .assertion(fields):
        return mapAssertionFields(fields)
      case .unsupported:
        throw PasskeyNativeException("Unsupported authorization credential response.")
      }
    } catch let error as PasskeyValidationException {
      throw error
    } catch let error as PasskeyNativeException {
      throw error
    } catch {
      throw mapAuthorizationError(error)
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

    guard platformController.supportsExcludedCredentials else {
      throw PasskeyValidationException("excludeCredentials requires iOS 17.4 or newer")
    }

    if #available(iOS 17.4, *) {
      request.excludedCredentials = credentials.map(platformCredentialDescriptor)
    }
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
