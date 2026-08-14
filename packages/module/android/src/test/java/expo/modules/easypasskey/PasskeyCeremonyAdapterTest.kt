package expo.modules.easypasskey

import androidx.credentials.CreateCustomCredentialResponse
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialResponse
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.NoCredentialException
import androidx.credentials.exceptions.domerrors.AbortError
import androidx.credentials.exceptions.publickey.CreatePublicKeyCredentialDomException
import androidx.credentials.exceptions.publickey.GetPublicKeyCredentialDomException
import android.os.Bundle
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class PasskeyCeremonyAdapterTest {
  @Test
  fun createNormalizesPublicKeyRegistrationJson() = runBlocking {
    val controller = FakePasskeyPlatformController(
      createResponse = CreatePublicKeyCredentialResponse(registrationJson()),
    )
    val adapter = PasskeyCeremonyAdapter(controller, supported = true)

    val response = adapter.create(createRequest())

    assertEquals("Y3JlZA", response["id"])
    assertEquals("public-key", response["type"])
    assertEquals("platform", response["authenticatorAttachment"])
    assertTrue(response["response"] is Map<*, *>)
    assertTrue(
      JSONObject(controller.lastCreateJson!!).getJSONObject("authenticatorSelection")
        .getString("userVerification") == "required"
    )
  }

  @Test
  fun getNormalizesPublicKeyAuthenticationJson() = runBlocking {
    val controller = FakePasskeyPlatformController(
      getResponse = GetCredentialResponse(PublicKeyCredential(authenticationJson())),
    )
    val adapter = PasskeyCeremonyAdapter(controller, supported = true)

    val response = adapter.get(getRequest())

    assertEquals("Y3JlZA", response["id"])
    assertEquals("public-key", response["type"])
    val payload = response["response"] as Map<*, *>
    assertEquals(null, payload["userHandle"])
    assertEquals(
      "preferred",
      JSONObject(controller.lastGetJson!!).getString("userVerification")
    )
  }

  @Test
  fun createMapsCancellation() {
    val adapter = PasskeyCeremonyAdapter(
      FakePasskeyPlatformController(createError = CreateCredentialCancellationException()),
      supported = true,
    )

    assertThrows(PasskeyCanceledException::class.java) {
      runBlocking { adapter.create(createRequest()) }
    }
  }

  @Test
  fun getMapsCancellation() {
    val adapter = PasskeyCeremonyAdapter(
      FakePasskeyPlatformController(getError = GetCredentialCancellationException()),
      supported = true,
    )

    assertThrows(PasskeyCanceledException::class.java) {
      runBlocking { adapter.get(getRequest()) }
    }
  }

  @Test
  fun createRejectsUnsupportedResponseType() {
    val adapter = PasskeyCeremonyAdapter(
      FakePasskeyPlatformController(
        createResponse = CreateCustomCredentialResponse("other", Bundle()),
      ),
      supported = true,
    )

    assertThrows(PasskeyNativeException::class.java) {
      runBlocking { adapter.create(createRequest()) }
    }
  }

  @Test
  fun getRejectsUnsupportedResponseType() {
    val adapter = PasskeyCeremonyAdapter(
      FakePasskeyPlatformController(
        getResponse = GetCredentialResponse(CustomCredential("other", Bundle())),
      ),
      supported = true,
    )

    assertThrows(PasskeyNativeException::class.java) {
      runBlocking { adapter.get(getRequest()) }
    }
  }

  @Test
  fun createMapsNoCredentialAndDomErrors() {
    val noCredential = PasskeyCeremonyAdapter(
      FakePasskeyPlatformController(createError = NoCredentialException("none")),
      supported = true,
    )
    val invalid = PasskeyCeremonyAdapter(
      FakePasskeyPlatformController(
        createError = CreatePublicKeyCredentialDomException(AbortError(), "dom"),
      ),
      supported = true,
    )

    assertThrows(PasskeyNoCredentialException::class.java) {
      runBlocking { noCredential.create(createRequest()) }
    }
    assertThrows(PasskeyInvalidCredentialException::class.java) {
      runBlocking { invalid.create(createRequest()) }
    }
  }

  @Test
  fun getMapsNoCredentialAndDomErrors() {
    val noCredential = PasskeyCeremonyAdapter(
      FakePasskeyPlatformController(getError = NoCredentialException("none")),
      supported = true,
    )
    val invalid = PasskeyCeremonyAdapter(
      FakePasskeyPlatformController(
        getError = GetPublicKeyCredentialDomException(AbortError(), "dom"),
      ),
      supported = true,
    )

    assertThrows(PasskeyNoCredentialException::class.java) {
      runBlocking { noCredential.get(getRequest()) }
    }
    assertThrows(PasskeyInvalidCredentialException::class.java) {
      runBlocking { invalid.get(getRequest()) }
    }
  }

  private fun createRequest(): PasskeyCreateRequest =
    PasskeyCreateRequest(
      mapOf(
        "challenge" to "Y2hhbGxlbmdl==",
        "rp" to mapOf("id" to "Example.COM", "name" to "Example"),
        "user" to mapOf(
          "id" to "dXNlcg==",
          "name" to "demo@example.com",
          "displayName" to "Demo User",
        ),
        "userVerification" to "required",
        "timeout" to 60_000,
      )
    )

  private fun getRequest(): PasskeyGetRequest =
    PasskeyGetRequest(
      mapOf(
        "challenge" to "YXV0aA==",
        "rpId" to "Example.COM",
        "timeout" to 30_000,
        "userVerification" to "preferred",
      )
    )

  private fun registrationJson(): String =
    """
    {
      "id": "Y3JlZA",
      "rawId": "Y3JlZA",
      "type": "public-key",
      "response": {
        "clientDataJSON": "Y2xpZW50",
        "attestationObject": "YXR0ZXN0"
      },
      "clientExtensionResults": {}
    }
    """.trimIndent()

  private fun authenticationJson(): String =
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
}

private class FakePasskeyPlatformController(
  private val createResponse: CreateCredentialResponse? = null,
  private val getResponse: GetCredentialResponse? = null,
  private val createError: Throwable? = null,
  private val getError: Throwable? = null,
) : PasskeyPlatformController {
  var lastCreateJson: String? = null
  var lastGetJson: String? = null

  override suspend fun create(requestJson: String): CreateCredentialResponse {
    lastCreateJson = requestJson
    createError?.let { throw it }
    return createResponse ?: error("missing create response")
  }

  override suspend fun get(requestJson: String): GetCredentialResponse {
    lastGetJson = requestJson
    getError?.let { throw it }
    return getResponse ?: error("missing get response")
  }
}
