import ExpoEasyPasskeyModule from "./ExpoEasyPasskeyModule.js";
import { createPasskeyApi } from "./passkeyApi.js";

export { PasskeyError, toPasskeyError } from "./errors.js";
export type {
  AttestationConveyancePreference,
  AuthenticationResponseJSON,
  Base64UrlString,
  CeremonyKind,
  CeremonySummary,
  ExpoEasyPasskeyNativeModule,
  NativeAuthenticationResponse,
  NativeCreateRequest,
  NativeCredentialDescriptor,
  NativeCredentialResponse,
  NativeGetRequest,
  NativeRegistrationResponse,
  PasskeyAvailability,
  PasskeyCapability,
  PasskeyErrorCode,
  PasskeyPlatform,
  PublicKeyCredentialCreationOptionsJSON,
  PublicKeyCredentialDescriptorJSON,
  PublicKeyCredentialRequestOptionsJSON,
  RegistrationResponseJSON,
  UserVerificationRequirement,
} from "./types.js";

const {
  authenticateWithPasskey,
  create,
  createPasskey,
  describeCeremony,
  get,
  getPasskeyAvailability,
  getPasskeyCapability,
  getPlatform,
  isSupported,
  normalizeChallenge,
  validateRelyingPartyId,
} = createPasskeyApi(ExpoEasyPasskeyModule);

export {
  authenticateWithPasskey,
  create,
  createPasskey,
  describeCeremony,
  get,
  getPasskeyAvailability,
  getPasskeyCapability,
  getPlatform,
  isSupported,
  normalizeChallenge,
  validateRelyingPartyId,
};
