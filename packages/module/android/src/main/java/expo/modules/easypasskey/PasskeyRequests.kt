package expo.modules.easypasskey

import org.json.JSONArray
import org.json.JSONObject

data class PasskeyCredentialDescriptor(
  val id: String,
  val transports: List<String>,
) {
  constructor(options: Map<String, Any?>) : this(
    id = PasskeyEncoding.normalizeBase64Url(options.stringValue("id")),
    transports = (options["transports"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
  )

  fun toJson(): JSONObject {
    val json = JSONObject()
      .put("type", "public-key")
      .put("id", id)

    if (transports.isNotEmpty()) {
      json.put("transports", JSONArray(transports))
    }

    return json
  }
}

data class PasskeyCreateRequest(
  val challenge: String,
  val rpId: String,
  val rpName: String,
  val userId: String,
  val userName: String,
  val userDisplayName: String,
  val origin: String?,
  val timeout: Number?,
  val userVerification: String?,
  val attestation: String?,
  val pubKeyCredParams: List<Map<String, Any?>>,
  val excludeCredentials: List<PasskeyCredentialDescriptor>,
  val authenticatorAttachment: String?,
  val residentKey: String?,
  val requireResidentKey: Boolean?,
) {
  constructor(options: Map<String, Any?>) : this(
    challenge = PasskeyEncoding.normalizeBase64Url(options.stringValue("challenge")),
    rpId = PasskeyInputValidator.validateRpId(options.mapValue("rp").stringValue("id")),
    rpName = options.mapValue("rp").stringValue("name"),
    userId = PasskeyEncoding.normalizeBase64Url(options.mapValue("user").stringValue("id")),
    userName = options.mapValue("user").stringValue("name"),
    userDisplayName = options.mapValue("user").stringValue("displayName"),
    origin = options.optionalStringValue("origin")?.let(PasskeyInputValidator::validateOrigin),
    timeout = options.optionalNumberValue("timeout"),
    userVerification = options.optionalStringValue("userVerification"),
    attestation = options.optionalStringValue("attestation"),
    pubKeyCredParams = options.optionalListValue("pubKeyCredParams"),
    excludeCredentials = options.optionalListValue("excludeCredentials").map(::PasskeyCredentialDescriptor),
    authenticatorAttachment = options.optionalStringValue("authenticatorAttachment"),
    residentKey = options.optionalStringValue("residentKey"),
    requireResidentKey = options["requireResidentKey"] as? Boolean,
  )

  fun toCredentialManagerJson(): String {
    val publicKey = JSONObject()
      .put("challenge", challenge)
      .put("rp", JSONObject().put("id", rpId).put("name", rpName))
      .put(
        "user",
        JSONObject()
          .put("id", userId)
          .put("name", userName)
          .put("displayName", userDisplayName)
      )
      .put(
        "pubKeyCredParams",
        if (pubKeyCredParams.isEmpty()) {
          JSONArray().put(JSONObject().put("type", "public-key").put("alg", -7))
        } else {
          pubKeyCredParams.toJsonArray()
        }
      )

    timeout?.let { publicKey.put("timeout", it) }
    attestation?.let { publicKey.put("attestation", it) }

    if (excludeCredentials.isNotEmpty()) {
      publicKey.put("excludeCredentials", JSONArray(excludeCredentials.map { it.toJson() }))
    }

    val selection = JSONObject()
    authenticatorAttachment?.let { selection.put("authenticatorAttachment", it) }
    residentKey?.let { selection.put("residentKey", it) }
    requireResidentKey?.let { selection.put("requireResidentKey", it) }
    userVerification?.let { selection.put("userVerification", it) }

    if (selection.length() > 0) {
      publicKey.put("authenticatorSelection", selection)
    }

    return publicKey.toString()
  }
}

data class PasskeyGetRequest(
  val challenge: String,
  val rpId: String,
  val origin: String?,
  val timeout: Number?,
  val userVerification: String?,
  val allowCredentials: List<PasskeyCredentialDescriptor>,
) {
  constructor(options: Map<String, Any?>) : this(
    challenge = PasskeyEncoding.normalizeBase64Url(options.stringValue("challenge")),
    rpId = PasskeyInputValidator.validateRpId(options.stringValue("rpId")),
    origin = options.optionalStringValue("origin")?.let(PasskeyInputValidator::validateOrigin),
    timeout = options.optionalNumberValue("timeout"),
    userVerification = options.optionalStringValue("userVerification"),
    allowCredentials = options.optionalListValue("allowCredentials").map(::PasskeyCredentialDescriptor),
  )

  fun toCredentialManagerJson(): String {
    val publicKey = JSONObject()
      .put("challenge", challenge)
      .put("rpId", rpId)

    timeout?.let { publicKey.put("timeout", it) }
    userVerification?.let { publicKey.put("userVerification", it) }

    if (allowCredentials.isNotEmpty()) {
      publicKey.put("allowCredentials", JSONArray(allowCredentials.map { it.toJson() }))
    }

    return publicKey.toString()
  }
}
