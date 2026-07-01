package expo.modules.easypasskey

import expo.modules.kotlin.functions.Coroutine
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class ExpoEasyPasskeyModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("ExpoEasyPasskey")

    Function("isSupported") {
      PasskeyCeremonyAdapter.isSupported
    }

    Function("getPlatform") {
      "android"
    }

    AsyncFunction("create") Coroutine { options: Map<String, Any?> ->
      val activity = appContext.currentActivity ?: throw PasskeyMissingActivityException()
      PasskeyCeremonyAdapter(activity).create(PasskeyCreateRequest(options))
    }

    AsyncFunction("get") Coroutine { options: Map<String, Any?> ->
      val activity = appContext.currentActivity ?: throw PasskeyMissingActivityException()
      PasskeyCeremonyAdapter(activity).get(PasskeyGetRequest(options))
    }

    AsyncFunction("normalizeChallenge") { challenge: String ->
      PasskeyEncoding.normalizeBase64Url(challenge)
    }

    AsyncFunction("validateRelyingPartyId") { rpId: String ->
      PasskeyInputValidator.validateRpId(rpId)
    }

    AsyncFunction("describeCeremony") { kind: String, challenge: String, rpId: String, origin: String ->
      PasskeyRustHelpers.describeCeremony(kind, challenge, rpId, origin)
    }
  }
}
