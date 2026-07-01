import XCTest
@testable import ExpoEasyPasskey

final class ExpoEasyPasskeyEncodingTests: XCTestCase {
  func testNormalizesBase64Url() throws {
    XCTAssertEqual(try PasskeyEncoding.normalizeBase64Url("YWJjZA=="), "YWJjZA")
    XCTAssertEqual(try PasskeyEncoding.normalizeBase64Url("+/8="), "-_8")
    XCTAssertThrowsError(try PasskeyEncoding.normalizeBase64Url("not valid base64!"))
  }

  func testValidatesRpIdLabels() throws {
    XCTAssertEqual(try PasskeyInputValidator.validateRpId("Example.COM"), "example.com")
    XCTAssertThrowsError(try PasskeyInputValidator.validateRpId("-example.com"))
    XCTAssertThrowsError(try PasskeyInputValidator.validateRpId("exämple.com"))
  }

  func testParsesCreateRequest() throws {
    let request = try PasskeyCreateRequest([
      "challenge": "Y2hhbGxlbmdl==",
      "rp": [
        "id": "Example.COM",
        "name": "Example"
      ],
      "user": [
        "id": "dXNlcg==",
        "name": "demo@example.com",
        "displayName": "Demo User"
      ],
      "origin": " https://example.com "
    ])

    XCTAssertEqual(request.challenge, "Y2hhbGxlbmdl")
    XCTAssertEqual(request.rpId, "example.com")
    XCTAssertEqual(request.userId, "dXNlcg")
    XCTAssertEqual(request.origin, "https://example.com")
  }

  func testParsesGetRequest() throws {
    let request = try PasskeyGetRequest([
      "challenge": "YXV0aA==",
      "rpId": "Example.COM",
      "origin": " https://example.com ",
      "allowCredentials": [
        [
          "id": "Y3JlZA==",
          "type": "public-key"
        ]
      ]
    ])

    XCTAssertEqual(request.challenge, "YXV0aA")
    XCTAssertEqual(request.rpId, "example.com")
    XCTAssertEqual(request.origin, "https://example.com")
    XCTAssertEqual(request.allowCredentials.first?.id, "Y3JlZA")
  }
}
