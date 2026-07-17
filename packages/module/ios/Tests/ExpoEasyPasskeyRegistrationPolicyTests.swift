import AuthenticationServices
import XCTest
@testable import ExpoEasyPasskey

final class ExpoEasyPasskeyRegistrationPolicyTests: XCTestCase {
  func testMapsSupportedAttestationPreferences() throws {
    XCTAssertEqual(
      try PasskeyRegistrationPolicy.attestationPreference(for: nil),
      .none
    )
    XCTAssertEqual(
      try PasskeyRegistrationPolicy.attestationPreference(for: "none"),
      .none
    )
    XCTAssertEqual(
      try PasskeyRegistrationPolicy.attestationPreference(for: "indirect"),
      .indirect
    )
    XCTAssertEqual(
      try PasskeyRegistrationPolicy.attestationPreference(for: "direct"),
      .direct
    )
    XCTAssertEqual(
      try PasskeyRegistrationPolicy.attestationPreference(for: "enterprise"),
      .enterprise
    )
  }

  func testRejectsUnsupportedAttestationPreference() throws {
    XCTAssertThrowsError(
      try PasskeyRegistrationPolicy.attestationPreference(for: "packed")
    ) { error in
      assertValidationError(error)
    }
  }

  func testAcceptsEs256AlgorithmOffers() throws {
    let request = try createRequest([
      "pubKeyCredParams": [
        ["type": "public-key", "alg": -257],
        ["type": "public-key", "alg": -7]
      ]
    ])

    XCTAssertNoThrow(try PasskeyRegistrationPolicy.resolve(request))
  }

  func testAcceptsEmptyAlgorithmOffersAsPlatformDefault() throws {
    let request = try createRequest([:])

    XCTAssertNoThrow(try PasskeyRegistrationPolicy.resolve(request))
  }

  func testRejectsAlgorithmOffersWithoutEs256() throws {
    let request = try createRequest([
      "pubKeyCredParams": [
        ["type": "public-key", "alg": -8],
        ["type": "public-key", "alg": -257]
      ]
    ])

    XCTAssertThrowsError(try PasskeyRegistrationPolicy.resolve(request)) { error in
      assertValidationError(error)
    }
  }

  func testRejectsCrossPlatformAttachmentBeforePresentation() throws {
    let request = try createRequest([
      "authenticatorAttachment": "cross-platform"
    ])

    XCTAssertThrowsError(try PasskeyRegistrationPolicy.resolve(request)) { error in
      assertValidationError(error)
    }
  }

  func testAcceptsPlatformAttachmentAndDiscoverableResidentKeys() throws {
    let platform = try createRequest([
      "authenticatorAttachment": "platform",
      "residentKey": "required",
      "requireResidentKey": true
    ])
    let preferred = try createRequest([
      "residentKey": "preferred",
      "requireResidentKey": false
    ])
    let legacyRequiredOnly = try createRequest([
      "requireResidentKey": true
    ])

    XCTAssertNoThrow(try PasskeyRegistrationPolicy.resolve(platform))
    XCTAssertNoThrow(try PasskeyRegistrationPolicy.resolve(preferred))
    XCTAssertNoThrow(try PasskeyRegistrationPolicy.resolve(legacyRequiredOnly))
  }

  func testRejectsDiscouragedResidentKeyAsIncompatible() throws {
    let request = try createRequest([
      "residentKey": "discouraged"
    ])

    XCTAssertThrowsError(try PasskeyRegistrationPolicy.resolve(request)) { error in
      assertValidationError(error)
    }
  }

  func testResolvedPolicyIncludesAttestationForNativeRequest() throws {
    let request = try createRequest([
      "attestation": "direct",
      "pubKeyCredParams": [
        ["type": "public-key", "alg": -7]
      ]
    ])

    let policy = try PasskeyRegistrationPolicy.resolve(request)

    XCTAssertEqual(policy.attestationPreference, .direct)
  }

  private func createRequest(_ overrides: [String: Any]) throws -> PasskeyCreateRequest {
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

  private func assertValidationError(_ error: Error) {
    guard let exception = error as? PasskeyValidationException else {
      XCTFail("Expected PasskeyValidationException, got \(error)")
      return
    }

    XCTAssertEqual(exception.code, "ERR_PASSKEY_VALIDATION")
  }
}
