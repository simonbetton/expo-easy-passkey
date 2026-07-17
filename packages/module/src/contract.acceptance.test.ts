import { createHash, generateKeyPairSync, sign } from "node:crypto";
import type { KeyObject } from "node:crypto";

import { jest } from "@jest/globals";
import {
  generateAuthenticationOptions,
  generateRegistrationOptions,
  verifyAuthenticationResponse,
  verifyRegistrationResponse,
} from "@simplewebauthn/server";
import { isoCBOR } from "@simplewebauthn/server/helpers";

import { createServerConfig } from "../../../apps/example-backend/src/server/config.js";
import type {
  ExpoEasyPasskeyNativeModule,
  NativeAuthenticationResponse,
  NativeCreateRequest,
  NativeGetRequest,
  NativeRegistrationResponse,
  PublicKeyCredentialCreationOptionsJSON,
  PublicKeyCredentialRequestOptionsJSON,
} from "./types.js";

const nativeModule: jest.Mocked<ExpoEasyPasskeyNativeModule> = {
  create: jest.fn<ExpoEasyPasskeyNativeModule["create"]>(),
  describeCeremony: jest.fn<ExpoEasyPasskeyNativeModule["describeCeremony"]>(),
  get: jest.fn<ExpoEasyPasskeyNativeModule["get"]>(),
  getPlatform: jest.fn<ExpoEasyPasskeyNativeModule["getPlatform"]>(
    () => "android"
  ),
  isSupported: jest.fn<ExpoEasyPasskeyNativeModule["isSupported"]>(() => true),
  normalizeChallenge: jest.fn<
    ExpoEasyPasskeyNativeModule["normalizeChallenge"]
  >((value) => Promise.resolve(value.replace(/=+$/u, ""))),
  validateRelyingPartyId: jest.fn<
    ExpoEasyPasskeyNativeModule["validateRelyingPartyId"]
  >((value) => Promise.resolve(value.toLowerCase())),
};

jest.unstable_mockModule("expo-modules-core", () => ({
  requireNativeModule: jest.fn(() => nativeModule),
}));

const { authenticateWithPasskey, createPasskey } =
  await import("expo-easy-passkey");

const rpId = "example.com";
const userId = new TextEncoder().encode("contract-test-user");

const fingerprint = (start: number): string =>
  Array.from({ length: 32 }, (_, index) =>
    (start + index).toString(16).padStart(2, "0")
  ).join(":");

const trustedOrigins = createServerConfig({
  ANDROID_SHA256_CERT_FINGERPRINTS: `${fingerprint(0)},${fingerprint(32)}`,
  PASSKEY_ORIGIN: "https://example.com",
  PASSKEY_RP_ID: rpId,
}).relyingParty.expectedOrigins;
const unknownOrigins = createServerConfig({
  ANDROID_SHA256_CERT_FINGERPRINTS: fingerprint(64),
  PASSKEY_ORIGIN: "https://example.com",
  PASSKEY_RP_ID: rpId,
}).relyingParty.expectedOrigins;
const [, unknownAndroidOrigin] = unknownOrigins;

if (!unknownAndroidOrigin) {
  throw new Error("Unknown Android origin fixture was not configured.");
}

const encodeBase64Url = (value: Uint8Array): string =>
  Buffer.from(value).toString("base64url");

const sha256 = (value: Uint8Array | string): Buffer =>
  createHash("sha256").update(value).digest();

const uint32 = (value: number): Buffer => {
  const bytes = Buffer.alloc(4);
  bytes.writeUInt32BE(value);
  return bytes;
};

const clientData = (
  type: "webauthn.create" | "webauthn.get",
  challenge: string,
  origin: string
): Buffer =>
  Buffer.from(
    JSON.stringify({
      challenge,
      crossOrigin: false,
      origin,
      type,
    })
  );

const contractBoundary = Symbol("contractBoundary");
type ContractBoundaryError = Error & { [contractBoundary]: true };

const isContractBoundaryError = (
  error: unknown
): error is ContractBoundaryError =>
  error instanceof Error &&
  contractBoundary in error &&
  error[contractBoundary] === true;

const createContractBoundaryError = (
  boundary: string,
  cause: unknown
): ContractBoundaryError =>
  Object.assign(new Error(`${boundary} failed`, { cause }), {
    [contractBoundary]: true as const,
  });

const atBoundary = async <Result>(
  boundary: string,
  operation: () => Promise<Result>
): Promise<Result> => {
  try {
    return await operation();
  } catch (error) {
    if (isContractBoundaryError(error)) {
      throw error;
    }

    throw createContractBoundaryError(boundary, error);
  }
};

class VirtualPlatformAuthenticator {
  readonly credentialId = Buffer.from("expo-easy-passkey-contract");
  readonly privateKey: KeyObject;
  readonly publicKey: KeyObject;

  constructor() {
    const keyPair = generateKeyPairSync("ec", {
      namedCurve: "prime256v1",
    });
    this.privateKey = keyPair.privateKey;
    this.publicKey = keyPair.publicKey;
  }

  create(request: NativeCreateRequest): NativeRegistrationResponse {
    const clientDataJSON = clientData(
      "webauthn.create",
      request.challenge,
      request.origin ?? ""
    );
    const publicJwk = this.publicKey.export({ format: "jwk" });

    if (!(publicJwk.x && publicJwk.y)) {
      throw new Error("generated P-256 key is missing coordinates");
    }

    const credentialPublicKey = isoCBOR.encode(
      new Map<number, number | Uint8Array>([
        [1, 2],
        [3, -7],
        [-1, 1],
        [-2, Buffer.from(publicJwk.x, "base64url")],
        [-3, Buffer.from(publicJwk.y, "base64url")],
      ])
    );
    const credentialIdLength = Buffer.alloc(2);
    credentialIdLength.writeUInt16BE(this.credentialId.length);
    const authData = Buffer.concat([
      sha256(request.rp.id),
      Buffer.from([0x45]),
      uint32(0),
      Buffer.alloc(16),
      credentialIdLength,
      this.credentialId,
      credentialPublicKey,
    ]);
    const attestationObject = isoCBOR.encode(
      new Map<string, Map<never, never> | string | Uint8Array>([
        ["fmt", "none"],
        ["attStmt", new Map()],
        ["authData", authData],
      ])
    );
    const id = encodeBase64Url(this.credentialId);

    return {
      authenticatorAttachment: "platform",
      clientExtensionResults: {},
      id,
      rawId: id,
      response: {
        attestationObject: encodeBase64Url(attestationObject),
        clientDataJSON: encodeBase64Url(clientDataJSON),
        transports: ["internal"],
      },
      type: "public-key",
    };
  }

  get(request: NativeGetRequest): NativeAuthenticationResponse {
    const clientDataJSON = clientData(
      "webauthn.get",
      request.challenge,
      request.origin ?? ""
    );
    const authData = Buffer.concat([
      sha256(request.rpId),
      Buffer.from([0x05]),
      uint32(1),
    ]);
    const signature = sign(
      "sha256",
      Buffer.concat([authData, sha256(clientDataJSON)]),
      this.privateKey
    );
    const id = encodeBase64Url(this.credentialId);

    return {
      authenticatorAttachment: "platform",
      clientExtensionResults: {},
      id,
      rawId: id,
      response: {
        authenticatorData: encodeBase64Url(authData),
        clientDataJSON: encodeBase64Url(clientDataJSON),
        signature: encodeBase64Url(signature),
        userHandle: null,
      },
      type: "public-key",
    };
  }
}

const assertIosRegistrationPolicy = (request: NativeCreateRequest): void => {
  if (request.authenticatorAttachment === "cross-platform") {
    throw Object.assign(
      new Error(
        "authenticatorAttachment cross-platform is not supported on iOS; only platform passkeys are implemented"
      ),
      { code: "ERR_PASSKEY_VALIDATION" as const }
    );
  }

  if (request.residentKey === "discouraged") {
    throw Object.assign(
      new Error(
        "residentKey discouraged is incompatible with iOS platform passkeys, which are always discoverable"
      ),
      { code: "ERR_PASSKEY_VALIDATION" as const }
    );
  }

  const pubKeyCredParams = request.pubKeyCredParams ?? [];
  if (
    pubKeyCredParams.length > 0 &&
    !pubKeyCredParams.some((parameter) => parameter.alg === -7)
  ) {
    throw Object.assign(
      new Error(
        "none of the offered public-key algorithms are supported on iOS; include ES256 (alg -7)"
      ),
      { code: "ERR_PASSKEY_VALIDATION" as const }
    );
  }
};

const runCeremonyContract = async (
  registrationOrigin: string,
  authenticationOrigin = registrationOrigin,
  registrationOverrides: Partial<PublicKeyCredentialCreationOptionsJSON> = {}
): Promise<void> => {
  const authenticator = new VirtualPlatformAuthenticator();
  nativeModule.create.mockImplementation((request) => {
    if (nativeModule.getPlatform() === "ios") {
      assertIosRegistrationPolicy(request);
    }

    return atBoundary("native registration mapping", () =>
      Promise.resolve(authenticator.create(request))
    );
  });
  nativeModule.get.mockImplementation((request) =>
    atBoundary("native authentication mapping", () =>
      Promise.resolve(authenticator.get(request))
    )
  );

  const registrationOptions = await generateRegistrationOptions({
    attestationType: "none",
    authenticatorSelection: {
      authenticatorAttachment: "platform",
      residentKey: "preferred",
      userVerification: "required",
    },
    rpID: rpId,
    rpName: "Contract Test",
    supportedAlgorithmIDs: [-7],
    userDisplayName: "Contract Test User",
    userID: userId,
    userName: "contract@example.com",
  });
  const registrationResponse = await atBoundary(
    "public package registration",
    () =>
      createPasskey({
        ...registrationOptions,
        ...registrationOverrides,
        origin: registrationOrigin,
      } as PublicKeyCredentialCreationOptionsJSON)
  );
  const credential = await atBoundary(
    "relying-party registration verification",
    async () => {
      const registration = await verifyRegistrationResponse({
        expectedChallenge: registrationOptions.challenge,
        expectedOrigin: [...trustedOrigins],
        expectedRPID: rpId,
        requireUserVerification: true,
        response: registrationResponse,
        supportedAlgorithmIDs: [-7],
      });

      expect(registration.verified).toBe(true);
      expect(registration.registrationInfo?.origin).toBe(registrationOrigin);

      if (!registration.registrationInfo) {
        throw new Error("registration did not return credential information");
      }

      return registration.registrationInfo.credential;
    }
  );

  const authenticationOptions = await generateAuthenticationOptions({
    allowCredentials: [
      {
        id: credential.id,
        transports: credential.transports,
      },
    ],
    rpID: rpId,
    userVerification: "required",
  });
  const authenticationResponse = await atBoundary(
    "public package authentication",
    () =>
      authenticateWithPasskey({
        ...authenticationOptions,
        origin: authenticationOrigin,
      } as PublicKeyCredentialRequestOptionsJSON)
  );
  await atBoundary("relying-party authentication verification", async () => {
    const authentication = await verifyAuthenticationResponse({
      credential,
      expectedChallenge: authenticationOptions.challenge,
      expectedOrigin: [...trustedOrigins],
      expectedRPID: rpId,
      requireUserVerification: true,
      response: authenticationResponse,
    });

    expect(authentication.verified).toBe(true);
    expect(authentication.authenticationInfo.origin).toBe(authenticationOrigin);
  });
};

describe("public package-to-relying-party contract", () => {
  beforeEach(() => {
    nativeModule.getPlatform.mockReturnValue("android");
  });

  it.each(trustedOrigins)(
    "verifies registration and authentication with configured origin %s",
    async (origin) => {
      await runCeremonyContract(origin);
    }
  );

  it("rejects registration from an unknown Android origin", async () => {
    await expect(runCeremonyContract(unknownAndroidOrigin)).rejects.toThrow(
      "relying-party registration verification failed"
    );
  });

  it("rejects authentication from an unknown Android origin", async () => {
    await expect(
      runCeremonyContract("https://example.com", unknownAndroidOrigin)
    ).rejects.toThrow("relying-party authentication verification failed");
  });
});

describe("iOS registration policy acceptance", () => {
  beforeEach(() => {
    nativeModule.getPlatform.mockReturnValue("ios");
  });

  it("accepts supported attestation, algorithm, attachment, and resident-key policy", async () => {
    await runCeremonyContract("https://example.com", "https://example.com", {
      attestation: "direct",
      authenticatorSelection: {
        authenticatorAttachment: "platform",
        requireResidentKey: true,
        residentKey: "required",
        userVerification: "required",
      },
      pubKeyCredParams: [
        { alg: -257, type: "public-key" },
        { alg: -7, type: "public-key" },
      ],
    });
  });

  it.each([
    {
      label: "cross-platform attachment",
      overrides: {
        authenticatorSelection: {
          authenticatorAttachment: "cross-platform" as const,
          residentKey: "preferred" as const,
          userVerification: "required" as const,
        },
      },
    },
    {
      label: "unsupported algorithms",
      overrides: {
        pubKeyCredParams: [
          { alg: -8, type: "public-key" as const },
          { alg: -257, type: "public-key" as const },
        ],
      },
    },
    {
      label: "discouraged resident key",
      overrides: {
        authenticatorSelection: {
          authenticatorAttachment: "platform" as const,
          residentKey: "discouraged" as const,
          userVerification: "required" as const,
        },
      },
    },
  ])(
    "rejects $label with ERR_PASSKEY_VALIDATION before ceremony completion",
    async ({ overrides }) => {
      await expect(
        runCeremonyContract("https://example.com", "https://example.com", overrides)
      ).rejects.toMatchObject({
        cause: expect.objectContaining({
          code: "ERR_PASSKEY_VALIDATION",
        }),
        message: "public package registration failed",
      });
      expect(nativeModule.create).toHaveBeenCalled();
    }
  );
});
