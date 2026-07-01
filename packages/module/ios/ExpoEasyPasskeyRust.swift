import Foundation

enum PasskeyRustHelpers {
  static func normalizeBase64Url(_ value: String) throws -> String {
    try mapRustError {
      try normalizeChallenge(challenge: value)
    }
  }

  static func validateRpId(_ rpId: String) throws -> String {
    try mapRustError {
      try validateRelyingPartyId(rpId: rpId)
    }
  }

  static func validateOrigin(_ origin: String) throws -> String {
    try mapRustError {
      try validateCeremonyOrigin(origin: origin)
    }
  }

  static func normalizeKind(_ kind: String) throws -> CeremonyKind {
    switch kind {
    case "create":
      return .create
    case "get":
      return .get
    default:
      throw PasskeyValidationException("unsupported ceremony kind")
    }
  }

  static func describeCeremony(
    kind: String,
    challenge: String,
    rpId: String,
    origin: String
  ) throws -> [String: Any] {
    let summary = try mapRustError {
      try ExpoEasyPasskey.describeCeremony(
        kind: normalizeKind(kind),
        challenge: challenge,
        rpId: rpId,
        origin: origin
      )
    }

    return [
      "kind": summary.kind == .create ? "create" : "get",
      "clientDataType": summary.clientDataType,
      "challenge": summary.challenge,
      "rpId": summary.rpId,
      "origin": summary.origin
    ]
  }

  private static func mapRustError<T>(_ operation: () throws -> T) throws -> T {
    do {
      return try operation()
    } catch let error as FfiError {
      switch error {
      case let .Validation(reason):
        throw PasskeyValidationException(reason)
      }
    } catch {
      throw PasskeyNativeException(error.localizedDescription)
    }
  }
}
