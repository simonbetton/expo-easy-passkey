import ExpoEasyPasskeyModule from "./ExpoEasyPasskeyModule.web.js";
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

const api = createPasskeyApi(ExpoEasyPasskeyModule);

export const authenticateWithPasskey = api.authenticateWithPasskey;
export const create = api.create;
export const createPasskey = api.createPasskey;
export const describeCeremony = api.describeCeremony;
export const get = api.get;
export const getPasskeyAvailability = api.getPasskeyAvailability;
export const getPasskeyCapability = api.getPasskeyCapability;
export const getPlatform = api.getPlatform;
export const isSupported = api.isSupported;
export const normalizeChallenge = api.normalizeChallenge;
export const validateRelyingPartyId = api.validateRelyingPartyId;
