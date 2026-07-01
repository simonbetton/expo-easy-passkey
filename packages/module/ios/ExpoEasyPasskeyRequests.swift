import Foundation

struct PasskeyCredentialDescriptor {
  let id: String
  let transports: [String]

  init(_ dictionary: [String: Any]) throws {
    guard let id = dictionary["id"] as? String else {
      throw PasskeyValidationException("credential descriptor id is required")
    }

    self.id = try PasskeyEncoding.normalizeBase64Url(id)
    self.transports = dictionary["transports"] as? [String] ?? []
  }

  var idData: Data {
    PasskeyEncoding.decodeBase64Url(id) ?? Data()
  }
}

struct PasskeyCreateRequest {
  let challenge: String
  let challengeData: Data
  let rpId: String
  let rpName: String
  let userId: String
  let userIdData: Data
  let userName: String
  let userDisplayName: String
  let origin: String?
  let timeout: Double?
  let userVerification: String?
  let attestation: String?
  let pubKeyCredParams: [[String: Any]]
  let excludeCredentials: [PasskeyCredentialDescriptor]
  let authenticatorAttachment: String?
  let residentKey: String?
  let requireResidentKey: Bool?

  init(_ options: [String: Any]) throws {
    guard let challenge = options["challenge"] as? String else {
      throw PasskeyValidationException("challenge is required")
    }
    guard let challengeData = PasskeyEncoding.decodeBase64Url(challenge) else {
      throw PasskeyValidationException("base64url value is invalid")
    }
    guard let rp = options["rp"] as? [String: Any],
          let rpId = rp["id"] as? String,
          let rpName = rp["name"] as? String else {
      throw PasskeyValidationException("rp.id and rp.name are required")
    }
    guard let user = options["user"] as? [String: Any],
          let userId = user["id"] as? String,
          let userName = user["name"] as? String,
          let userDisplayName = user["displayName"] as? String else {
      throw PasskeyValidationException("user.id, user.name, and user.displayName are required")
    }
    guard let userIdData = PasskeyEncoding.decodeBase64Url(userId) else {
      throw PasskeyValidationException("base64url value is invalid")
    }

    self.challenge = try PasskeyEncoding.normalizeBase64Url(challenge)
    self.challengeData = challengeData
    self.rpId = try PasskeyInputValidator.validateRpId(rpId)
    self.rpName = rpName
    self.userId = try PasskeyEncoding.normalizeBase64Url(userId)
    self.userIdData = userIdData
    self.userName = userName
    self.userDisplayName = userDisplayName
    self.origin = try (options["origin"] as? String).map(PasskeyInputValidator.validateOrigin)
    self.timeout = options["timeout"] as? Double
    self.userVerification = options["userVerification"] as? String
    self.attestation = options["attestation"] as? String
    self.pubKeyCredParams = options["pubKeyCredParams"] as? [[String: Any]] ?? []
    self.excludeCredentials = try (options["excludeCredentials"] as? [[String: Any]] ?? [])
      .map(PasskeyCredentialDescriptor.init)
    self.authenticatorAttachment = options["authenticatorAttachment"] as? String
    self.residentKey = options["residentKey"] as? String
    self.requireResidentKey = options["requireResidentKey"] as? Bool
  }
}

struct PasskeyGetRequest {
  let challenge: String
  let challengeData: Data
  let rpId: String
  let origin: String?
  let timeout: Double?
  let userVerification: String?
  let allowCredentials: [PasskeyCredentialDescriptor]

  init(_ options: [String: Any]) throws {
    guard let challenge = options["challenge"] as? String else {
      throw PasskeyValidationException("challenge is required")
    }
    guard let challengeData = PasskeyEncoding.decodeBase64Url(challenge) else {
      throw PasskeyValidationException("base64url value is invalid")
    }
    guard let rpId = options["rpId"] as? String else {
      throw PasskeyValidationException("rpId is required")
    }

    self.challenge = try PasskeyEncoding.normalizeBase64Url(challenge)
    self.challengeData = challengeData
    self.rpId = try PasskeyInputValidator.validateRpId(rpId)
    self.origin = try (options["origin"] as? String).map(PasskeyInputValidator.validateOrigin)
    self.timeout = options["timeout"] as? Double
    self.userVerification = options["userVerification"] as? String
    self.allowCredentials = try (options["allowCredentials"] as? [[String: Any]] ?? [])
      .map(PasskeyCredentialDescriptor.init)
  }
}
