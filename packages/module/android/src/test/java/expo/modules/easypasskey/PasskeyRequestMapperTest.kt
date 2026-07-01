package expo.modules.easypasskey

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class PasskeyRequestMapperTest {
  @Test
  fun rustBackedValidationRejectsInvalidInputs() {
    assertThrows(PasskeyValidationException::class.java) {
      PasskeyEncoding.normalizeBase64Url("not valid base64!")
    }
    assertThrows(PasskeyValidationException::class.java) {
      PasskeyInputValidator.validateRpId("exämple.com")
    }
  }

  @Test
  fun createRequestBuildsCredentialManagerJson() {
    val request = PasskeyCreateRequest(
      mapOf(
        "challenge" to "Y2hhbGxlbmdl==",
        "rp" to mapOf("id" to "Example.COM", "name" to "Example"),
        "user" to mapOf(
          "id" to "dXNlcg==",
          "name" to "demo@example.com",
          "displayName" to "Demo User",
        ),
        "userVerification" to "required",
        "residentKey" to "preferred",
        "pubKeyCredParams" to listOf(mapOf("type" to "public-key", "alg" to -7)),
      )
    )

    val publicKey = JSONObject(request.toCredentialManagerJson())

    assertEquals("Y2hhbGxlbmdl", publicKey.getString("challenge"))
    assertEquals("example.com", publicKey.getJSONObject("rp").getString("id"))
    assertEquals("dXNlcg", publicKey.getJSONObject("user").getString("id"))
    assertEquals(
      "required",
      publicKey.getJSONObject("authenticatorSelection").getString("userVerification")
    )
  }

  @Test
  fun getRequestBuildsCredentialManagerJson() {
    val request = PasskeyGetRequest(
      mapOf(
        "challenge" to "YXV0aA==",
        "rpId" to "Example.COM",
        "allowCredentials" to listOf(mapOf("id" to "Y3JlZA==", "type" to "public-key")),
      )
    )

    val publicKey = JSONObject(request.toCredentialManagerJson())

    assertEquals("YXV0aA", publicKey.getString("challenge"))
    assertEquals("example.com", publicKey.getString("rpId"))
    assertEquals(
      "Y3JlZA",
      publicKey.getJSONArray("allowCredentials").getJSONObject(0).getString("id")
    )
  }

  @Test
  fun responseMapperNormalizesCredentialManagerJson() {
    val response = JSONObject(
      """
      {
        "id": "Y3JlZA",
        "rawId": "Y3JlZA",
        "type": "public-key",
        "response": {
          "clientDataJSON": "Y2xpZW50",
          "authenticatorData": "YXV0aERhdGE",
          "signature": "c2ln",
          "userHandle": null
        },
        "clientExtensionResults": {}
      }
      """.trimIndent()
    ).toWebAuthnResponseMap()

    assertEquals("Y3JlZA", response["id"])
    assertEquals("public-key", response["type"])
    assertEquals("platform", response["authenticatorAttachment"])
    assertTrue(response["response"] is Map<*, *>)
  }

  @Test
  fun mapsCredentialManagerErrorsToSpecificPasskeyErrors() {
    class NoCredentialException(message: String) : RuntimeException(message)
    class GetPublicKeyCredentialDomException(message: String) : RuntimeException(message)

    assertTrue(
      mapCredentialManagerError(
        NoCredentialException("No credential available"),
        "fallback"
      ) is PasskeyNoCredentialException
    )
    assertTrue(
      mapCredentialManagerError(
        GetPublicKeyCredentialDomException("Invalid credential response"),
        "fallback"
      ) is PasskeyInvalidCredentialException
    )
    assertTrue(
      mapCredentialManagerError(RuntimeException(), "fallback") is PasskeyNativeException
    )
  }
}
