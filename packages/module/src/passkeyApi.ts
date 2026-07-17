import { PasskeyError, toPasskeyError } from "./errors.js";
import type {
  AuthenticationResponseJSON,
  ExpoEasyPasskeyNativeModule,
  NativeCreateRequest,
  NativeGetRequest,
  PasskeyAvailability,
  PasskeyCapability,
  PasskeyPlatform,
  PublicKeyCredentialCreationOptionsJSON,
  PublicKeyCredentialDescriptorJSON,
  PublicKeyCredentialRequestOptionsJSON,
  RegistrationResponseJSON,
} from "./types.js";

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const invalidResponse = (message: string): PasskeyError =>
  new PasskeyError(message, "ERR_PASSKEY_INVALID_RESPONSE");

const validationError = (message: string): PasskeyError =>
  new PasskeyError(message, "ERR_PASSKEY_VALIDATION");

const isNonEmptyString = (value: unknown): value is string =>
  typeof value === "string" && value.length > 0;

const getString = (value: Record<string, unknown>, key: string): string => {
  const item = value[key];

  if (!isNonEmptyString(item)) {
    throw invalidResponse(`native response missing ${key}`);
  }

  return item;
};

const getPublicKeyType = (value: Record<string, unknown>): "public-key" => {
  const type = getString(value, "type");

  if (type !== "public-key") {
    throw invalidResponse("native response type must be public-key");
  }

  return type;
};

const getOptionalAttachment = (
  value: Record<string, unknown>
): "platform" | "cross-platform" | undefined => {
  const attachment = value.authenticatorAttachment;

  if (attachment === undefined) {
    return undefined;
  }

  if (attachment === "platform" || attachment === "cross-platform") {
    return attachment;
  }

  throw invalidResponse("native response has invalid authenticatorAttachment");
};

const getClientExtensionResults = (
  value: Record<string, unknown>
): Record<string, unknown> => {
  if (isRecord(value.clientExtensionResults)) {
    return value.clientExtensionResults;
  }

  throw invalidResponse(
    "native response clientExtensionResults must be an object"
  );
};

const getOptionalStringArray = (
  value: Record<string, unknown>,
  key: string
): string[] | undefined => {
  const item = value[key];

  if (item === undefined) {
    return undefined;
  }

  if (
    !Array.isArray(item) ||
    !item.every((entry) => typeof entry === "string")
  ) {
    throw invalidResponse(`native response ${key} must be an array of strings`);
  }

  return item;
};

const userVerificationValues = [
  "required",
  "preferred",
  "discouraged",
] as const;
const attachmentValues = ["platform", "cross-platform"] as const;
const residentKeyValues = ["discouraged", "preferred", "required"] as const;
const attestationValues = [
  "none",
  "indirect",
  "direct",
  "enterprise",
] as const;

const validateOptionalEnum = (
  value: unknown,
  allowed: readonly string[],
  field: string
): void => {
  if (value === undefined) {
    return;
  }

  if (typeof value !== "string" || !allowed.includes(value)) {
    throw validationError(`${field} is invalid`);
  }
};

const validateOptionalNumber = (value: unknown, field: string): void => {
  if (value !== undefined && typeof value !== "number") {
    throw validationError(`${field} must be a number`);
  }
};

const validateOptionalString = (value: unknown, field: string): void => {
  if (value !== undefined && typeof value !== "string") {
    throw validationError(`${field} must be a string`);
  }
};

const validateCredentialDescriptors: (
  credentials: unknown,
  field: string
) => asserts credentials is PublicKeyCredentialDescriptorJSON[] | undefined = (
  credentials,
  field
) => {
  if (credentials === undefined) {
    return;
  }

  if (!Array.isArray(credentials)) {
    throw validationError(`${field} must be an array`);
  }

  for (const [index, credential] of credentials.entries()) {
    if (!isRecord(credential)) {
      throw validationError(`${field}[${index}] must be an object`);
    }

    if (!isNonEmptyString(credential.id)) {
      throw validationError(`${field}[${index}].id is required`);
    }

    if (credential.type !== "public-key") {
      throw validationError(`${field}[${index}].type must be public-key`);
    }

    const { transports } = credential;
    if (
      transports !== undefined &&
      (!Array.isArray(transports) ||
        !transports.every((transport) => typeof transport === "string"))
    ) {
      throw validationError(`${field}[${index}].transports must be strings`);
    }
  }
};

const validatePubKeyCredParams = (value: unknown): void => {
  if (value === undefined) {
    return;
  }

  if (!Array.isArray(value)) {
    throw validationError("pubKeyCredParams must be an array");
  }

  for (const [index, param] of value.entries()) {
    if (!isRecord(param)) {
      throw validationError(`pubKeyCredParams[${index}] must be an object`);
    }

    if (param.type !== "public-key") {
      throw validationError(
        `pubKeyCredParams[${index}].type must be public-key`
      );
    }

    if (typeof param.alg !== "number") {
      throw validationError(`pubKeyCredParams[${index}].alg must be a number`);
    }
  }
};

const validateCreateOptions: (
  options: unknown
) => asserts options is PublicKeyCredentialCreationOptionsJSON = (options) => {
  if (!isRecord(options)) {
    throw validationError("registration options must be an object");
  }

  if (!isNonEmptyString(options.challenge)) {
    throw validationError("challenge is required");
  }

  if (!isRecord(options.rp)) {
    throw validationError("rp is required");
  }

  if (
    !isNonEmptyString(options.rp.id) ||
    !isNonEmptyString(options.rp.name)
  ) {
    throw validationError("rp.id and rp.name are required");
  }

  if (!isRecord(options.user)) {
    throw validationError("user is required");
  }

  if (
    !isNonEmptyString(options.user.id) ||
    !isNonEmptyString(options.user.name) ||
    !isNonEmptyString(options.user.displayName)
  ) {
    throw validationError(
      "user.id, user.name, and user.displayName are required"
    );
  }

  validateOptionalString(options.origin, "origin");
  validateOptionalNumber(options.timeout, "timeout");
  validateOptionalEnum(options.attestation, attestationValues, "attestation");
  validatePubKeyCredParams(options.pubKeyCredParams);
  validateCredentialDescriptors(
    options.excludeCredentials,
    "excludeCredentials"
  );

  if (options.authenticatorSelection !== undefined) {
    if (!isRecord(options.authenticatorSelection)) {
      throw validationError("authenticatorSelection must be an object");
    }

    validateOptionalEnum(
      options.authenticatorSelection.authenticatorAttachment,
      attachmentValues,
      "authenticatorSelection.authenticatorAttachment"
    );
    validateOptionalEnum(
      options.authenticatorSelection.residentKey,
      residentKeyValues,
      "authenticatorSelection.residentKey"
    );
    validateOptionalEnum(
      options.authenticatorSelection.userVerification,
      userVerificationValues,
      "authenticatorSelection.userVerification"
    );

    if (
      options.authenticatorSelection.requireResidentKey !== undefined &&
      typeof options.authenticatorSelection.requireResidentKey !== "boolean"
    ) {
      throw validationError(
        "authenticatorSelection.requireResidentKey must be a boolean"
      );
    }
  }
};

const validateGetOptions: (
  options: unknown
) => asserts options is PublicKeyCredentialRequestOptionsJSON = (options) => {
  if (!isRecord(options)) {
    throw validationError("authentication options must be an object");
  }

  if (!isNonEmptyString(options.challenge)) {
    throw validationError("challenge is required");
  }

  if (!isNonEmptyString(options.rpId)) {
    throw validationError("rpId is required");
  }

  validateOptionalString(options.origin, "origin");
  validateOptionalNumber(options.timeout, "timeout");
  validateOptionalEnum(
    options.userVerification,
    userVerificationValues,
    "userVerification"
  );
  validateCredentialDescriptors(options.allowCredentials, "allowCredentials");
};

export const createPasskeyApi = (
  ExpoEasyPasskeyModule: ExpoEasyPasskeyNativeModule
) => {
  const normalizeBase64Url = (value: string): Promise<string> =>
    ExpoEasyPasskeyModule.normalizeChallenge(value);

  const normalizeResponseBase64Url = async (value: string): Promise<string> => {
    try {
      return await normalizeBase64Url(value);
    } catch (error) {
      const detail = error instanceof Error ? `: ${error.message}` : "";
      throw invalidResponse(
        `native response contains invalid base64url${detail}`
      );
    }
  };

  const validateRpId = (rpId: string): Promise<string> =>
    ExpoEasyPasskeyModule.validateRelyingPartyId(rpId);

  const normalizeCredentialDescriptors = (
    credentials?: PublicKeyCredentialDescriptorJSON[]
  ): Promise<PublicKeyCredentialDescriptorJSON[]> | undefined => {
    if (!credentials) {
      return undefined;
    }

    return Promise.all(
      credentials.map(async (credential) => ({
        ...credential,
        id: await normalizeBase64Url(credential.id),
      }))
    );
  };

  const normalizeOptionalUserHandle = async (
    userHandle: unknown
  ): Promise<string | null | undefined> => {
    if (userHandle === undefined) {
      return undefined;
    }

    if (typeof userHandle === "string") {
      return await normalizeResponseBase64Url(userHandle);
    }

    if (userHandle === null) {
      return null;
    }

    throw invalidResponse("native response userHandle must be a string or null");
  };

  const assertRegistrationResponse = async (
    response: unknown
  ): Promise<RegistrationResponseJSON> => {
    if (!isRecord(response) || !isRecord(response.response)) {
      throw invalidResponse("invalid registration response");
    }

    const [id, rawId, attestationObject, clientDataJSON] = await Promise.all([
      normalizeResponseBase64Url(getString(response, "id")),
      normalizeResponseBase64Url(getString(response, "rawId")),
      normalizeResponseBase64Url(
        getString(response.response, "attestationObject")
      ),
      normalizeResponseBase64Url(getString(response.response, "clientDataJSON")),
    ]);

    return {
      authenticatorAttachment: getOptionalAttachment(response),
      clientExtensionResults: getClientExtensionResults(response),
      id,
      rawId,
      response: {
        attestationObject,
        clientDataJSON,
        transports: getOptionalStringArray(response.response, "transports"),
      },
      type: getPublicKeyType(response),
    };
  };

  const assertAuthenticationResponse = async (
    response: unknown
  ): Promise<AuthenticationResponseJSON> => {
    if (!isRecord(response) || !isRecord(response.response)) {
      throw invalidResponse("invalid authentication response");
    }

    const { userHandle } = response.response;
    const [
      id,
      rawId,
      authenticatorData,
      clientDataJSON,
      signature,
      normalizedUserHandle,
    ] = await Promise.all([
      normalizeResponseBase64Url(getString(response, "id")),
      normalizeResponseBase64Url(getString(response, "rawId")),
      normalizeResponseBase64Url(
        getString(response.response, "authenticatorData")
      ),
      normalizeResponseBase64Url(getString(response.response, "clientDataJSON")),
      normalizeResponseBase64Url(getString(response.response, "signature")),
      normalizeOptionalUserHandle(userHandle),
    ]);

    return {
      authenticatorAttachment: getOptionalAttachment(response),
      clientExtensionResults: getClientExtensionResults(response),
      id,
      rawId,
      response: {
        authenticatorData,
        clientDataJSON,
        signature,
        userHandle: normalizedUserHandle,
      },
      type: getPublicKeyType(response),
    };
  };

  const isSupported = (): boolean => ExpoEasyPasskeyModule.isSupported();

  const getPlatform = (): PasskeyPlatform => ExpoEasyPasskeyModule.getPlatform();

  const getPasskeyAvailability = (): PasskeyAvailability => ({
    platform: getPlatform(),
    supported: isSupported(),
  });

  /** @deprecated Use getPasskeyAvailability for new code. */
  const getPasskeyCapability = (): PasskeyCapability => getPasskeyAvailability();

  const getNativeCreateRequest = async (
    options: PublicKeyCredentialCreationOptionsJSON
  ): Promise<NativeCreateRequest> => {
    validateCreateOptions(options);

    const {
      authenticatorAttachment,
      requireResidentKey,
      residentKey,
      userVerification,
    } = options.authenticatorSelection ?? {};
    const [challenge, excludeCredentials, rpId, userId] = await Promise.all([
      normalizeBase64Url(options.challenge),
      normalizeCredentialDescriptors(options.excludeCredentials),
      validateRpId(options.rp.id),
      normalizeBase64Url(options.user.id),
    ]);

    return {
      attestation: options.attestation,
      authenticatorAttachment,
      challenge,
      excludeCredentials,
      origin: options.origin,
      pubKeyCredParams: options.pubKeyCredParams,
      requireResidentKey,
      residentKey,
      rp: {
        id: rpId,
        name: options.rp.name,
      },
      timeout: options.timeout,
      user: {
        ...options.user,
        id: userId,
      },
      userVerification,
    };
  };

  const getNativeGetRequest = async (
    options: PublicKeyCredentialRequestOptionsJSON
  ): Promise<NativeGetRequest> => {
    validateGetOptions(options);

    const [allowCredentials, challenge, rpId] = await Promise.all([
      normalizeCredentialDescriptors(options.allowCredentials),
      normalizeBase64Url(options.challenge),
      validateRpId(options.rpId),
    ]);

    return {
      allowCredentials,
      challenge,
      origin: options.origin,
      rpId,
      timeout: options.timeout,
      userVerification: options.userVerification,
    };
  };

  const createPasskey = async (
    options: PublicKeyCredentialCreationOptionsJSON
  ): Promise<RegistrationResponseJSON> => {
    let request: NativeCreateRequest;

    try {
      request = await getNativeCreateRequest(options);
    } catch (error) {
      throw toPasskeyError(error, "ERR_PASSKEY_VALIDATION");
    }

    let response: unknown;

    try {
      response = await ExpoEasyPasskeyModule.create(request);
    } catch (error) {
      throw toPasskeyError(error, "ERR_PASSKEY_CREATE");
    }

    try {
      return await assertRegistrationResponse(response);
    } catch (error) {
      throw toPasskeyError(error, "ERR_PASSKEY_INVALID_RESPONSE");
    }
  };

  /** @deprecated Use createPasskey for new code. */
  const create = createPasskey;

  const authenticateWithPasskey = async (
    options: PublicKeyCredentialRequestOptionsJSON
  ): Promise<AuthenticationResponseJSON> => {
    let request: NativeGetRequest;

    try {
      request = await getNativeGetRequest(options);
    } catch (error) {
      throw toPasskeyError(error, "ERR_PASSKEY_VALIDATION");
    }

    let response: unknown;

    try {
      response = await ExpoEasyPasskeyModule.get(request);
    } catch (error) {
      throw toPasskeyError(error, "ERR_PASSKEY_GET");
    }

    try {
      return await assertAuthenticationResponse(response);
    } catch (error) {
      throw toPasskeyError(error, "ERR_PASSKEY_INVALID_RESPONSE");
    }
  };

  /** @deprecated Use authenticateWithPasskey for new code. */
  const get = authenticateWithPasskey;

  const normalizeChallenge = ExpoEasyPasskeyModule.normalizeChallenge.bind(
    ExpoEasyPasskeyModule
  );
  const validateRelyingPartyId =
    ExpoEasyPasskeyModule.validateRelyingPartyId.bind(ExpoEasyPasskeyModule);
  const describeCeremony = ExpoEasyPasskeyModule.describeCeremony.bind(
    ExpoEasyPasskeyModule
  );

  return {
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
};
