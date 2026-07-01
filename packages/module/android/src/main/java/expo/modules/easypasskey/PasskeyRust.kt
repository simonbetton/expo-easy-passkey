package expo.modules.easypasskey

import uniffi.expo_easy_passkey_ffi.CeremonyKind as RustCeremonyKind
import uniffi.expo_easy_passkey_ffi.FfiException
import uniffi.expo_easy_passkey_ffi.describeCeremony
import uniffi.expo_easy_passkey_ffi.normalizeChallenge
import uniffi.expo_easy_passkey_ffi.validateCeremonyOrigin
import uniffi.expo_easy_passkey_ffi.validateRelyingPartyId

object PasskeyRustHelpers {
  fun normalizeBase64Url(value: String): String =
    mapRustError {
      normalizeChallenge(value)
    }

  fun validateRpId(rpId: String): String =
    mapRustError {
      validateRelyingPartyId(rpId)
    }

  fun validateOrigin(origin: String): String =
    mapRustError {
      validateCeremonyOrigin(origin)
    }

  fun normalizeKind(kind: String): RustCeremonyKind =
    when (kind) {
      "create" -> RustCeremonyKind.CREATE
      "get" -> RustCeremonyKind.GET
      else -> throw PasskeyValidationException("unsupported ceremony kind")
    }

  fun describeCeremony(
    kind: String,
    challenge: String,
    rpId: String,
    origin: String,
  ): Map<String, Any?> {
    val summary = mapRustError {
      describeCeremony(normalizeKind(kind), challenge, rpId, origin)
    }

    return mapOf(
      "kind" to if (summary.kind == RustCeremonyKind.CREATE) "create" else "get",
      "clientDataType" to summary.clientDataType,
      "challenge" to summary.challenge,
      "rpId" to summary.rpId,
      "origin" to summary.origin,
    )
  }

  private inline fun <T> mapRustError(operation: () -> T): T =
    try {
      operation()
    } catch (error: FfiException.Validation) {
      throw PasskeyValidationException(error.reason)
    } catch (error: FfiException) {
      throw PasskeyNativeException(error.message ?: "Rust passkey helper failed.")
    }
}
