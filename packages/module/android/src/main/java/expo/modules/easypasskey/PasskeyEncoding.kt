package expo.modules.easypasskey

import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject

object PasskeyEncoding {
  fun normalizeBase64Url(input: String): String = PasskeyRustHelpers.normalizeBase64Url(input)

  fun decodeBase64Url(input: String): ByteArray =
    try {
      Base64.decode(input, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    } catch (error: IllegalArgumentException) {
      throw PasskeyValidationException("base64url value is invalid")
    }

  fun encodeBase64Url(bytes: ByteArray): String =
    Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
}

object PasskeyInputValidator {
  fun normalizeKind(kind: String): String {
    PasskeyRustHelpers.normalizeKind(kind)

    if (kind == "create" || kind == "get") {
      return kind
    }

    throw PasskeyValidationException("unsupported ceremony kind")
  }

  fun validateRpId(rpId: String): String = PasskeyRustHelpers.validateRpId(rpId)

  fun validateOrigin(origin: String): String = PasskeyRustHelpers.validateOrigin(origin)
}

fun Map<String, Any?>.stringValue(key: String): String =
  this[key] as? String ?: throw PasskeyValidationException("$key is required")

fun Map<String, Any?>.optionalStringValue(key: String): String? = this[key] as? String

fun Map<String, Any?>.optionalNumberValue(key: String): Number? = this[key] as? Number

@Suppress("UNCHECKED_CAST")
fun Map<String, Any?>.mapValue(key: String): Map<String, Any?> =
  this[key] as? Map<String, Any?> ?: throw PasskeyValidationException("$key is required")

@Suppress("UNCHECKED_CAST")
fun Map<String, Any?>.optionalListValue(key: String): List<Map<String, Any?>> =
  this[key] as? List<Map<String, Any?>> ?: emptyList()

fun Iterable<Map<String, Any?>>.toJsonArray(): JSONArray {
  val array = JSONArray()

  forEach { value ->
    array.put(JSONObject(value))
  }

  return array
}
