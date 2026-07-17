import AuthenticationServices
import Foundation

struct PasskeyRegistrationPolicy {
  struct Resolved {
    let attestationPreference: ASAuthorizationPublicKeyCredentialAttestationKind
  }

  /// COSE algorithms AuthenticationServices platform passkeys can satisfy.
  static let supportedAlgorithms: Set<Int> = [
    -7 // ES256
  ]

  static func resolve(_ request: PasskeyCreateRequest) throws -> Resolved {
    try validateAuthenticatorAttachment(request.authenticatorAttachment)
    try validateResidentKey(
      residentKey: request.residentKey,
      requireResidentKey: request.requireResidentKey
    )
    try validatePublicKeyAlgorithms(request.pubKeyCredParams)

    return Resolved(
      attestationPreference: try attestationPreference(for: request.attestation)
    )
  }

  static func attestationPreference(
    for value: String?
  ) throws -> ASAuthorizationPublicKeyCredentialAttestationKind {
    switch value {
    case nil, "none":
      return .none
    case "indirect":
      return .indirect
    case "direct":
      return .direct
    case "enterprise":
      return .enterprise
    default:
      throw PasskeyValidationException(
        "attestation preference is unsupported on iOS"
      )
    }
  }

  private static func validateAuthenticatorAttachment(_ attachment: String?) throws {
    switch attachment {
    case nil, "platform":
      return
    case "cross-platform":
      throw PasskeyValidationException(
        "authenticatorAttachment cross-platform is not supported on iOS; only platform passkeys are implemented"
      )
    default:
      throw PasskeyValidationException(
        "authenticatorAttachment is unsupported on iOS"
      )
    }
  }

  private static func validateResidentKey(
    residentKey: String?,
    requireResidentKey: Bool?
  ) throws {
    switch residentKey {
    case nil, "preferred", "required":
      break
    case "discouraged":
      throw PasskeyValidationException(
        "residentKey discouraged is incompatible with iOS platform passkeys, which are always discoverable"
      )
    default:
      throw PasskeyValidationException(
        "residentKey is unsupported on iOS"
      )
    }

    // Legacy requireResidentKey false means discoverable credentials are optional.
    // Platform passkeys remain discoverable, which still satisfies that request.
    // requireResidentKey true is also satisfied because platform passkeys are resident.
    _ = requireResidentKey
  }

  private static func validatePublicKeyAlgorithms(
    _ pubKeyCredParams: [[String: Any]]
  ) throws {
    guard !pubKeyCredParams.isEmpty else {
      return
    }

    let algorithms = pubKeyCredParams.compactMap(coseAlgorithm)
    guard algorithms.contains(where: { supportedAlgorithms.contains($0) }) else {
      throw PasskeyValidationException(
        "none of the offered public-key algorithms are supported on iOS; include ES256 (alg -7)"
      )
    }
  }

  private static func coseAlgorithm(_ parameter: [String: Any]) -> Int? {
    if let alg = parameter["alg"] as? Int {
      return alg
    }

    if let alg = parameter["alg"] as? NSNumber {
      return alg.intValue
    }

    return nil
  }
}
