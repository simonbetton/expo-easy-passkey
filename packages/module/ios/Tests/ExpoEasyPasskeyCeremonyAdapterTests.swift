import AuthenticationServices
import ExpoModulesCore
import XCTest
@testable import ExpoEasyPasskey

final class ExpoEasyPasskeyCeremonyAdapterTests: XCTestCase {
  func testMapsRegistrationSuccess() async throws {
    let credentialID = Data("cred".utf8)
    let clientData = Data("client".utf8)
    let attestation = Data("attest".utf8)
    let controller = FakePasskeyPlatformController(
      result: .registration(
        PasskeyRegistrationFields(
          credentialID: credentialID,
          rawClientDataJSON: clientData,
          rawAttestationObject: attestation
        )
      )
    )
    let adapter = ExpoEasyPasskeyCeremonyAdapter(platformController: controller)

    let request = try createRequest()
    let response = try await adapter.create(
      request,
      policy: try PasskeyRegistrationPolicy.resolve(request)
    )

    XCTAssertEqual(response["id"] as? String, PasskeyEncoding.encodeBase64Url(credentialID))
    XCTAssertEqual(response["rawId"] as? String, PasskeyEncoding.encodeBase64Url(credentialID))
    XCTAssertEqual(response["type"] as? String, "public-key")
    XCTAssertEqual(response["authenticatorAttachment"] as? String, "platform")
    let payload = response["response"] as? [String: Any]
    XCTAssertEqual(
      payload?["clientDataJSON"] as? String,
      PasskeyEncoding.encodeBase64Url(clientData)
    )
    XCTAssertEqual(
      payload?["attestationObject"] as? String,
      PasskeyEncoding.encodeBase64Url(attestation)
    )
  }

  func testMapsAssertionSuccessWithNullUserHandle() async throws {
    let credentialID = Data("cred".utf8)
    let controller = FakePasskeyPlatformController(
      result: .assertion(
        PasskeyAssertionFields(
          credentialID: credentialID,
          rawClientDataJSON: Data("client".utf8),
          rawAuthenticatorData: Data("auth".utf8),
          signature: Data("sig".utf8),
          userID: nil
        )
      )
    )
    let adapter = ExpoEasyPasskeyCeremonyAdapter(platformController: controller)

    let response = try await adapter.get(try getRequest())
    let payload = response["response"] as? [String: Any]

    XCTAssertEqual(response["id"] as? String, PasskeyEncoding.encodeBase64Url(credentialID))
    XCTAssertTrue(payload?["userHandle"] is NSNull)
  }

  func testMapsUserCancellation() async {
    let controller = FakePasskeyPlatformController(
      error: ASAuthorizationError(_nsError: NSError(
        domain: ASAuthorizationError.errorDomain,
        code: ASAuthorizationError.Code.canceled.rawValue
      ))
    )
    let adapter = ExpoEasyPasskeyCeremonyAdapter(platformController: controller)

    await assertErrorCode(
      { try await adapter.get(try getRequest()) },
      "ERR_PASSKEY_CANCELED"
    )
  }

  func testMapsUnsupportedCredentialType() async {
    let controller = FakePasskeyPlatformController(result: .unsupported)
    let adapter = ExpoEasyPasskeyCeremonyAdapter(platformController: controller)

    await assertErrorCode(
      { try await adapter.get(try getRequest()) },
      "ERR_PASSKEY_NATIVE"
    )
  }

  func testRejectsRegistrationMissingAttestationObject() async {
    let controller = FakePasskeyPlatformController(
      result: .registration(
        PasskeyRegistrationFields(
          credentialID: Data("cred".utf8),
          rawClientDataJSON: Data("client".utf8),
          rawAttestationObject: nil
        )
      )
    )
    let adapter = ExpoEasyPasskeyCeremonyAdapter(platformController: controller)

    await assertErrorCode(
      {
        let request = try createRequest()
        try await adapter.create(
          request,
          policy: try PasskeyRegistrationPolicy.resolve(request)
        )
      },
      "ERR_PASSKEY_NATIVE"
    )
  }

  func testRejectsExcludeCredentialsWhenPlatformDoesNotSupportThem() async {
    let controller = FakePasskeyPlatformController(
      supportsExcludedCredentials: false,
      result: .unsupported
    )
    let adapter = ExpoEasyPasskeyCeremonyAdapter(platformController: controller)

    await assertErrorCode(
      {
        let request = try createRequest([
          "excludeCredentials": [
            ["id": "Y3JlZA", "type": "public-key"]
          ]
        ])
        try await adapter.create(
          request,
          policy: try PasskeyRegistrationPolicy.resolve(request)
        )
      },
      "ERR_PASSKEY_VALIDATION"
    )
    XCTAssertTrue(controller.performedRequests.isEmpty)
  }

  func testAppliesUserVerificationPreferencesOnCreateAndGet() async throws {
    let controller = FakePasskeyPlatformController(
      result: .registration(
        PasskeyRegistrationFields(
          credentialID: Data("cred".utf8),
          rawClientDataJSON: Data("client".utf8),
          rawAttestationObject: Data("attest".utf8)
        )
      )
    )
    let adapter = ExpoEasyPasskeyCeremonyAdapter(platformController: controller)

    let create = try createRequest(["userVerification": "required"])
    _ = try await adapter.create(
      create,
      policy: try PasskeyRegistrationPolicy.resolve(create)
    )
    let registration = try XCTUnwrap(
      controller.performedRequests.last as? ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest
    )
    XCTAssertEqual(registration.userVerificationPreference, .required)

    controller.result = .assertion(
      PasskeyAssertionFields(
        credentialID: Data("cred".utf8),
        rawClientDataJSON: Data("client".utf8),
        rawAuthenticatorData: Data("auth".utf8),
        signature: Data("sig".utf8),
        userID: Data("user".utf8)
      )
    )
    _ = try await adapter.get(try getRequest(["userVerification": "discouraged"]))
    let discouraged = try XCTUnwrap(
      controller.performedRequests.last as? ASAuthorizationPlatformPublicKeyCredentialAssertionRequest
    )
    XCTAssertEqual(discouraged.userVerificationPreference, .discouraged)

    _ = try await adapter.get(try getRequest(["userVerification": "preferred"]))
    let preferred = try XCTUnwrap(
      controller.performedRequests.last as? ASAuthorizationPlatformPublicKeyCredentialAssertionRequest
    )
    XCTAssertEqual(preferred.userVerificationPreference, .preferred)
  }

  private func createRequest(_ overrides: [String: Any] = [:]) throws -> PasskeyCreateRequest {
    var options: [String: Any] = [
      "challenge": "Y2hhbGxlbmdl",
      "rp": [
        "id": "example.com",
        "name": "Example"
      ],
      "user": [
        "id": "dXNlcg",
        "name": "demo@example.com",
        "displayName": "Demo User"
      ]
    ]

    for (key, value) in overrides {
      options[key] = value
    }

    return try PasskeyCreateRequest(options)
  }

  private func getRequest(_ overrides: [String: Any] = [:]) throws -> PasskeyGetRequest {
    var options: [String: Any] = [
      "challenge": "YXV0aA",
      "rpId": "example.com"
    ]

    for (key, value) in overrides {
      options[key] = value
    }

    return try PasskeyGetRequest(options)
  }

  private func assertErrorCode(
    _ work: () async throws -> some Any,
    _ code: String
  ) async {
    do {
      _ = try await work()
      XCTFail("Expected \(code)")
    } catch let exception as Exception {
      XCTAssertEqual(exception.code, code)
    } catch {
      XCTFail("Expected coded exception \(code), got \(error)")
    }
  }
}

private final class FakePasskeyPlatformController: PasskeyPlatformControlling {
  var supportsExcludedCredentials: Bool
  var result: PasskeyPlatformCredential
  var error: Error?
  private(set) var performedRequests: [ASAuthorizationRequest] = []

  init(
    supportsExcludedCredentials: Bool = true,
    result: PasskeyPlatformCredential = .unsupported,
    error: Error? = nil
  ) {
    self.supportsExcludedCredentials = supportsExcludedCredentials
    self.result = result
    self.error = error
  }

  func perform(_ requests: [ASAuthorizationRequest]) async throws -> PasskeyPlatformCredential {
    performedRequests.append(contentsOf: requests)
    if let error {
      throw error
    }

    return result
  }
}
