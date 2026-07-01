package expo.modules.easypasskey

import expo.modules.kotlin.exception.CodedException

class PasskeyValidationException(message: String) :
  CodedException("ERR_PASSKEY_VALIDATION", message, null)

class PasskeyUnsupportedException :
  CodedException(
    "ERR_PASSKEY_UNSUPPORTED",
    "Passkey ceremonies are not supported on this Android runtime.",
    null
  )

class PasskeyMissingActivityException :
  CodedException(
    "ERR_PASSKEY_ACTIVITY",
    "Unable to find a foreground activity for the passkey ceremony.",
    null
  )

class PasskeyCanceledException :
  CodedException("ERR_PASSKEY_CANCELED", "The passkey ceremony was canceled.", null)

class PasskeyNoCredentialException(message: String) :
  CodedException("ERR_PASSKEY_NO_CREDENTIAL", message, null)

class PasskeyInvalidCredentialException(message: String) :
  CodedException("ERR_PASSKEY_INVALID_CREDENTIAL", message, null)

class PasskeyNativeException(message: String) :
  CodedException("ERR_PASSKEY_NATIVE", message, null)
