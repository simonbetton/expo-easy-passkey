import ExpoModulesCore

final class PasskeyValidationException: Exception, @unchecked Sendable {
  init(_ message: String) {
    super.init(
      name: "PasskeyValidationException",
      description: message,
      code: "ERR_PASSKEY_VALIDATION"
    )
  }
}

final class PasskeyUnsupportedException: Exception, @unchecked Sendable {
  init() {
    super.init(
      name: "PasskeyUnsupportedException",
      description: "Passkey ceremonies are not supported on this iOS runtime.",
      code: "ERR_PASSKEY_UNSUPPORTED"
    )
  }
}

final class PasskeyMissingPresentationContextException: Exception, @unchecked Sendable {
  init() {
    super.init(
      name: "PasskeyMissingPresentationContextException",
      description: "Unable to find a presentation anchor for the passkey ceremony.",
      code: "ERR_PASSKEY_PRESENTATION_CONTEXT"
    )
  }
}

final class PasskeyCanceledException: Exception, @unchecked Sendable {
  init() {
    super.init(
      name: "PasskeyCanceledException",
      description: "The passkey ceremony was canceled.",
      code: "ERR_PASSKEY_CANCELED"
    )
  }
}

final class PasskeyNoCredentialException: Exception, @unchecked Sendable {
  init(_ message: String) {
    super.init(
      name: "PasskeyNoCredentialException",
      description: message,
      code: "ERR_PASSKEY_NO_CREDENTIAL"
    )
  }
}

final class PasskeyInvalidCredentialException: Exception, @unchecked Sendable {
  init(_ message: String) {
    super.init(
      name: "PasskeyInvalidCredentialException",
      description: message,
      code: "ERR_PASSKEY_INVALID_CREDENTIAL"
    )
  }
}

final class PasskeyNativeException: Exception, @unchecked Sendable {
  init(_ message: String) {
    super.init(
      name: "PasskeyNativeException",
      description: message,
      code: "ERR_PASSKEY_NATIVE"
    )
  }
}
