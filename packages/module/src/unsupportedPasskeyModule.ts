import { PasskeyError } from "./errors.js";
import type { ExpoEasyPasskeyNativeModule, PasskeyPlatform } from "./types.js";

export const WEB_UNSUPPORTED_MESSAGE =
  "Passkey ceremonies are not supported on web. Browser WebAuthn support is a planned future feature; use another sign-in method for now.";

export const MISSING_NATIVE_MODULE_MESSAGE =
  "Passkey ceremonies require the expo-easy-passkey native module. Use a development build or production build; Expo Go cannot load custom native modules.";

export const createUnsupportedPasskeyModule = (
  platform: PasskeyPlatform,
  message: string
): ExpoEasyPasskeyNativeModule => {
  const rejectUnsupported = (): Promise<never> =>
    Promise.reject(new PasskeyError(message, "ERR_PASSKEY_UNSUPPORTED"));

  return {
    create: rejectUnsupported,
    describeCeremony: rejectUnsupported,
    get: rejectUnsupported,
    getPlatform: () => platform,
    isSupported: () => false,
    normalizeChallenge: rejectUnsupported,
    validateRelyingPartyId: rejectUnsupported,
  };
};
