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

const atBoundary = async <Result>(
  boundary: string,
  operation: () => Promise<Result>
): Promise<Result> => {
  try {
    return await operation();
  } catch (error) {
    throw new Error(`${boundary} failed`, { cause: error });
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

const runCeremonyContract = async (origin: string): Promise<void> => {
  const authenticator = new VirtualPlatformAuthenticator();
  nativeModule.create.mockImplementation((request) =>
    Promise.resolve(authenticator.create(request))
  );
  nativeModule.get.mockImplementation((request) =>
    Promise.resolve(authenticator.get(request))
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
        origin,
      } as PublicKeyCredentialCreationOptionsJSON)
  );
  const credential = await atBoundary(
    "relying-party registration verification",
    async () => {
      const registration = await verifyRegistrationResponse({
        expectedChallenge: registrationOptions.challenge,
        expectedOrigin: origin,
        expectedRPID: rpId,
        requireUserVerification: true,
        response: registrationResponse,
        supportedAlgorithmIDs: [-7],
      });

      expect(registration.verified).toBe(true);
      expect(registration.registrationInfo?.origin).toBe(origin);

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
        origin,
      } as PublicKeyCredentialRequestOptionsJSON)
  );
  await atBoundary("relying-party authentication verification", async () => {
    const authentication = await verifyAuthenticationResponse({
      credential,
      expectedChallenge: authenticationOptions.challenge,
      expectedOrigin: origin,
      expectedRPID: rpId,
      requireUserVerification: true,
      response: authenticationResponse,
    });

    expect(authentication.verified).toBe(true);
    expect(authentication.authenticationInfo.origin).toBe(origin);
  });
};

describe("public package-to-relying-party contract", () => {
  it.each([
    ["HTTPS", "https://example.com"],
    [
      "Android native",
      "android:apk-key-hash:ATzQY0Ta_4vFzYmCG9wzK2PqYRbBrAqfTVqLwYui4Bk",
    ],
  ])(
    "verifies registration and authentication with an %s origin",
    async (_fixture, origin) => {
      await runCeremonyContract(origin);
    }
  );
});
