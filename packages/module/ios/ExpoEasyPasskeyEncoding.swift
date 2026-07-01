import Foundation

enum PasskeyEncoding {
  static func normalizeBase64Url(_ input: String) throws -> String {
    try PasskeyRustHelpers.normalizeBase64Url(input)
  }

  static func decodeBase64Url(_ input: String) -> Data? {
    var base64 = input
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    let padding = (4 - base64.count % 4) % 4
    base64.append(String(repeating: "=", count: padding))

    return Data(base64Encoded: base64)
  }

  static func encodeBase64Url(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: #"=+$"#, with: "", options: .regularExpression)
  }
}

enum PasskeyInputValidator {
  static func normalizeKind(_ kind: String) throws -> String {
    _ = try PasskeyRustHelpers.normalizeKind(kind)

    if kind == "create" || kind == "get" {
      return kind
    }

    throw PasskeyValidationException("unsupported ceremony kind")
  }

  static func validateRpId(_ rpId: String) throws -> String {
    try PasskeyRustHelpers.validateRpId(rpId)
  }

  static func validateOrigin(_ origin: String) throws -> String {
    try PasskeyRustHelpers.validateOrigin(origin)
  }
}
