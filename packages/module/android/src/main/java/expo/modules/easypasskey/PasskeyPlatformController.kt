package expo.modules.easypasskey

import android.app.Activity
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPublicKeyCredentialOption

/**
 * Injectable Credential Manager facade for ceremony adapters.
 * Production uses [AndroidPasskeyPlatformController]; tests inject a fake.
 */
interface PasskeyPlatformController {
  suspend fun create(requestJson: String): CreateCredentialResponse

  suspend fun get(requestJson: String): GetCredentialResponse
}

class AndroidPasskeyPlatformController(
  private val activity: Activity,
  private val credentialManager: CredentialManager = CredentialManager.create(activity),
) : PasskeyPlatformController {
  override suspend fun create(requestJson: String): CreateCredentialResponse =
    credentialManager.createCredential(
      context = activity,
      request = CreatePublicKeyCredentialRequest(requestJson),
    )

  override suspend fun get(requestJson: String): GetCredentialResponse {
    val option = GetPublicKeyCredentialOption(requestJson)
    return credentialManager.getCredential(
      context = activity,
      request = GetCredentialRequest(listOf(option)),
    )
  }
}
