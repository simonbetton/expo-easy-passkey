package expo.modules.easypasskey

import android.app.Activity
import android.os.Build
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialCancellationException
import org.json.JSONArray
import org.json.JSONObject

class PasskeyCeremonyAdapter(
  private val activity: Activity,
) {
  private val credentialManager = CredentialManager.create(activity)

  suspend fun create(request: PasskeyCreateRequest): Map<String, Any?> {
    if (!isSupported) {
      throw PasskeyUnsupportedException()
    }

    try {
      val response = credentialManager.createCredential(
        context = activity,
        request = CreatePublicKeyCredentialRequest(request.toCredentialManagerJson()),
      )
      val publicKeyResponse = response as? CreatePublicKeyCredentialResponse
        ?: throw PasskeyNativeException("Credential Manager returned an unsupported create response.")

      return JSONObject(publicKeyResponse.registrationResponseJson).toWebAuthnResponseMap()
    } catch (error: CreateCredentialCancellationException) {
      throw PasskeyCanceledException()
    } catch (error: PasskeyNativeException) {
      throw error
    } catch (error: Throwable) {
      throw mapCredentialManagerError(error, "Credential Manager create ceremony failed.")
    }
  }

  suspend fun get(request: PasskeyGetRequest): Map<String, Any?> {
    if (!isSupported) {
      throw PasskeyUnsupportedException()
    }

    try {
      val option = GetPublicKeyCredentialOption(request.toCredentialManagerJson())
      val response = credentialManager.getCredential(
        context = activity,
        request = GetCredentialRequest(listOf(option)),
      )
      val credential = response.credential as? PublicKeyCredential
        ?: throw PasskeyNativeException("Credential Manager returned an unsupported get response.")

      return JSONObject(credential.authenticationResponseJson).toWebAuthnResponseMap()
    } catch (error: GetCredentialCancellationException) {
      throw PasskeyCanceledException()
    } catch (error: PasskeyNativeException) {
      throw error
    } catch (error: Throwable) {
      throw mapCredentialManagerError(error, "Credential Manager get ceremony failed.")
    }
  }

  companion object {
    val isSupported: Boolean
      get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
  }
}

internal fun mapCredentialManagerError(error: Throwable, fallbackMessage: String): Throwable {
  val message = error.message ?: fallbackMessage

  return when (error::class.java.simpleName) {
    "NoCredentialException" -> PasskeyNoCredentialException(message)
    "CreatePublicKeyCredentialDomException",
    "GetPublicKeyCredentialDomException" -> PasskeyInvalidCredentialException(message)
    else -> PasskeyNativeException(message)
  }
}

fun JSONObject.toWebAuthnResponseMap(): Map<String, Any?> {
  val id = optString("id")
  val rawId = optString("rawId", id)
  val response = optJSONObject("response") ?: JSONObject()

  return mapOf(
    "id" to id,
    "rawId" to rawId,
    "type" to optString("type", "public-key"),
    "response" to response.toMap(),
    "clientExtensionResults" to (optJSONObject("clientExtensionResults")?.toMap() ?: emptyMap<String, Any?>()),
    "authenticatorAttachment" to optString("authenticatorAttachment", "platform"),
  )
}

fun JSONObject.toMap(): Map<String, Any?> {
  val result = linkedMapOf<String, Any?>()
  val keys = keys()

  while (keys.hasNext()) {
    val key = keys.next()
    result[key] = normalizeJsonValue(opt(key))
  }

  return result
}

private fun JSONArray.toListValue(): List<Any?> {
  val result = mutableListOf<Any?>()

  for (index in 0 until length()) {
    result.add(normalizeJsonValue(opt(index)))
  }

  return result
}

private fun normalizeJsonValue(value: Any?): Any? =
  when (value) {
    JSONObject.NULL -> null
    is JSONObject -> value.toMap()
    is JSONArray -> value.toListValue()
    else -> value
  }
