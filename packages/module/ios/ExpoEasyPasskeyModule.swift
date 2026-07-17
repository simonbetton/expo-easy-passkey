import AuthenticationServices
import ExpoModulesCore

public class ExpoEasyPasskeyModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoEasyPasskey")

    Function("isSupported") {
      ExpoEasyPasskeyCeremonyAdapter.isSupported
    }

    Function("getPlatform") {
      "ios"
    }

    AsyncFunction("create") { (_ options: [String: Any]) async throws -> [String: Any] in
      let request = try PasskeyCreateRequest(options)
      let policy = try PasskeyRegistrationPolicy.resolve(request)
      let adapter = try await self.makeCeremonyAdapter()
      return try await adapter.create(request, policy: policy)
    }

    AsyncFunction("get") { (_ options: [String: Any]) async throws -> [String: Any] in
      let request = try PasskeyGetRequest(options)
      let adapter = try await self.makeCeremonyAdapter()
      return try await adapter.get(request)
    }

    AsyncFunction("normalizeChallenge") { (challenge: String) async throws -> String in
      try PasskeyEncoding.normalizeBase64Url(challenge)
    }

    AsyncFunction("validateRelyingPartyId") { (rpId: String) async throws -> String in
      try PasskeyInputValidator.validateRpId(rpId)
    }

    AsyncFunction("describeCeremony") { (
      kind: String,
      challenge: String,
      rpId: String,
      origin: String
    ) async throws -> [String: Any] in
      try PasskeyRustHelpers.describeCeremony(
        kind: kind,
        challenge: challenge,
        rpId: rpId,
        origin: origin
      )
    }
  }

  @MainActor
  private func makeCeremonyAdapter() throws -> ExpoEasyPasskeyCeremonyAdapter {
    guard let viewController = appContext?.utilities?.currentViewController() else {
      throw PasskeyMissingPresentationContextException()
    }

    return ExpoEasyPasskeyCeremonyAdapter(presentationAnchorProvider: {
      viewController.view.window ?? UIWindow()
    })
  }
}
