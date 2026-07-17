import { jest } from "@jest/globals";

import type {
  ExpoEasyPasskeyNativeModule,
  NativeAuthenticationResponse,
  NativeRegistrationResponse,
  PublicKeyCredentialCreationOptionsJSON,
  PublicKeyCredentialRequestOptionsJSON,
} from "./types.js";

const nativeModule: jest.Mocked<ExpoEasyPasskeyNativeModule> = {
  create: jest.fn<ExpoEasyPasskeyNativeModule["create"]>(),
  describeCeremony: jest.fn<ExpoEasyPasskeyNativeModule["describeCeremony"]>(),
  get: jest.fn<ExpoEasyPasskeyNativeModule["get"]>(),
  getPlatform: jest.fn<ExpoEasyPasskeyNativeModule["getPlatform"]>(() => "ios"),
  isSupported: jest.fn<ExpoEasyPasskeyNativeModule["isSupported"]>(() => true),
  normalizeChallenge:
    jest.fn<ExpoEasyPasskeyNativeModule["normalizeChallenge"]>(),
  validateRelyingPartyId:
    jest.fn<ExpoEasyPasskeyNativeModule["validateRelyingPartyId"]>(),
};

jest.unstable_mockModule("expo-modules-core", () => ({
  Platform: { OS: "ios" },
  requireNativeModule: jest.fn(() => nativeModule),
  requireOptionalNativeModule: jest.fn(() => nativeModule),
}));

const moduleExports = await import("./index.js");

const registrationOptions = (): PublicKeyCredentialCreationOptionsJSON => ({
  attestation: "none",
  authenticatorSelection: {
    authenticatorAttachment: "platform",
    requireResidentKey: true,
    residentKey: "preferred",
    userVerification: "required",
  },
  challenge: "Y2hhbGxlbmdl==",
  excludeCredentials: [{ id: "ZXhjbHVkZQ==", type: "public-key" }],
  origin: "https://example.com",
  pubKeyCredParams: [{ alg: -7, type: "public-key" }],
  rp: {
    id: "Example.COM",
    name: "Example",
  },
  timeout: 60_000,
  user: {
    displayName: "Demo User",
    id: "dXNlcg==",
    name: "demo@example.com",
  },
});

const authenticationOptions = (): PublicKeyCredentialRequestOptionsJSON => ({
  allowCredentials: [{ id: "Y3JlZA==", type: "public-key" }],
  challenge: "YXV0aA==",
  origin: "https://example.com",
  rpId: "Example.COM",
  timeout: 30_000,
  userVerification: "preferred",
});

const registrationResponse = (): NativeRegistrationResponse => ({
  authenticatorAttachment: "platform",
  clientExtensionResults: { appid: false },
  id: "Y3JlZA",
  rawId: "Y3JlZA",
  response: {
    attestationObject: "YXR0ZXN0YXRpb24",
    clientDataJSON: "Y2xpZW50",
    transports: ["internal"],
  },
  type: "public-key",
});

const authenticationResponse = (): NativeAuthenticationResponse => ({
  authenticatorAttachment: "platform",
  clientExtensionResults: {},
  id: "Y3JlZA",
  rawId: "Y3JlZA",
  response: {
    authenticatorData: "YXV0aERhdGE",
    clientDataJSON: "Y2xpZW50",
    signature: "c2ln",
    userHandle: "dXNlcg==",
  },
  type: "public-key",
});

describe("expo-easy-passkey", () => {
  beforeEach(() => {
    nativeModule.create.mockReset();
    nativeModule.describeCeremony.mockReset();
    nativeModule.get.mockReset();
    nativeModule.normalizeChallenge.mockReset();
    nativeModule.validateRelyingPartyId.mockReset();
    nativeModule.normalizeChallenge.mockImplementation((value: string) =>
      Promise.resolve(
        value
          .trim()
          .replaceAll("+", "-")
          .replaceAll("/", "_")
          .replace(/=+$/u, "")
      )
    );
    nativeModule.validateRelyingPartyId.mockImplementation((rpId: string) =>
      Promise.resolve(rpId.trim().toLowerCase())
    );
  });

  it("forwards support and platform probes", () => {
    expect(moduleExports.isSupported()).toBe(true);
    expect(moduleExports.getPlatform()).toBe("ios");
    expect(moduleExports.getPasskeyAvailability()).toEqual({
      platform: "ios",
      supported: true,
    });
  });

  it("normalizes and forwards supported WebAuthn registration options", async () => {
    nativeModule.create.mockResolvedValue(registrationResponse());

    const result = await moduleExports.createPasskey(registrationOptions());

    expect(nativeModule.create).toHaveBeenCalledWith({
      attestation: "none",
      authenticatorAttachment: "platform",
      challenge: "Y2hhbGxlbmdl",
      excludeCredentials: [{ id: "ZXhjbHVkZQ", type: "public-key" }],
      origin: "https://example.com",
      pubKeyCredParams: [{ alg: -7, type: "public-key" }],
      requireResidentKey: true,
      residentKey: "preferred",
      rp: {
        id: "example.com",
        name: "Example",
      },
      timeout: 60_000,
      user: {
        displayName: "Demo User",
        id: "dXNlcg",
        name: "demo@example.com",
      },
      userVerification: "required",
    });
    expect(result).toEqual({
      authenticatorAttachment: "platform",
      clientExtensionResults: { appid: false },
      id: "Y3JlZA",
      rawId: "Y3JlZA",
      response: {
        attestationObject: "YXR0ZXN0YXRpb24",
        clientDataJSON: "Y2xpZW50",
        transports: ["internal"],
      },
      type: "public-key",
    });
  });

  it("validates registration response shape", async () => {
    const invalidRegistrationResponse: unknown = {
      clientExtensionResults: {},
      id: "Y3JlZA",
      rawId: "Y3JlZA",
      response: {
        clientDataJSON: "Y2xpZW50",
      },
      type: "public-key",
    };

    nativeModule.create.mockResolvedValue(
      invalidRegistrationResponse as NativeRegistrationResponse
    );

    await expect(
      moduleExports.createPasskey(registrationOptions())
    ).rejects.toMatchObject({
      code: "ERR_PASSKEY_INVALID_RESPONSE",
    });
  });

  it("rejects invalid registration response attachment values", async () => {
    const invalidRegistrationResponse = {
      ...registrationResponse(),
      authenticatorAttachment: "roaming",
    } as unknown as NativeRegistrationResponse;

    nativeModule.create.mockResolvedValue(invalidRegistrationResponse);

    await expect(
      moduleExports.createPasskey(registrationOptions())
    ).rejects.toMatchObject({
      code: "ERR_PASSKEY_INVALID_RESPONSE",
    });
  });

  it("rejects invalid registration response transports", async () => {
    const invalidRegistrationResponse = {
      ...registrationResponse(),
      response: {
        ...registrationResponse().response,
        transports: ["internal", 42],
      },
    } as unknown as NativeRegistrationResponse;

    nativeModule.create.mockResolvedValue(invalidRegistrationResponse);

    await expect(
      moduleExports.createPasskey(registrationOptions())
    ).rejects.toMatchObject({
      code: "ERR_PASSKEY_INVALID_RESPONSE",
    });
  });

  it("reports invalid registration options as validation errors", async () => {
    const invalidOptions = {
      ...registrationOptions(),
      authenticatorSelection: {
        userVerification: "sometimes",
      },
    } as unknown as PublicKeyCredentialCreationOptionsJSON;

    await expect(
      moduleExports.createPasskey(invalidOptions)
    ).rejects.toMatchObject({
      code: "ERR_PASSKEY_VALIDATION",
    });
    expect(nativeModule.create).not.toHaveBeenCalled();
  });

  it("uses the create fallback code for uncoded native create failures", async () => {
    nativeModule.create.mockRejectedValue(new Error("Native create failed"));

    await expect(
      moduleExports.createPasskey(registrationOptions())
    ).rejects.toMatchObject({
      code: "ERR_PASSKEY_CREATE",
    });
  });

  it("keeps deprecated create alias wired to createPasskey", async () => {
    nativeModule.create.mockResolvedValue(registrationResponse());

    await moduleExports.create(registrationOptions());

    expect(nativeModule.create).toHaveBeenCalledTimes(1);
  });

  it("normalizes and forwards authentication options", async () => {
    nativeModule.get.mockResolvedValue(authenticationResponse());

    const result = await moduleExports.authenticateWithPasskey(
      authenticationOptions()
    );

    expect(nativeModule.get).toHaveBeenCalledWith({
      allowCredentials: [{ id: "Y3JlZA", type: "public-key" }],
      challenge: "YXV0aA",
      origin: "https://example.com",
      rpId: "example.com",
      timeout: 30_000,
      userVerification: "preferred",
    });
    expect(result.response.userHandle).toBe("dXNlcg");
  });

  it("preserves native error codes", async () => {
    const nativeError = Object.assign(new Error("Canceled"), {
      code: "ERR_PASSKEY_CANCELED",
    });

    nativeModule.get.mockRejectedValue(nativeError);

    await expect(
      moduleExports.authenticateWithPasskey({
        challenge: "YXV0aA",
        rpId: "example.com",
      })
    ).rejects.toMatchObject({
      code: "ERR_PASSKEY_CANCELED",
    });
  });

  it("rejects invalid authentication response user handles", async () => {
    const invalidAuthenticationResponse = {
      ...authenticationResponse(),
      response: {
        ...authenticationResponse().response,
        userHandle: 42,
      },
    } as unknown as NativeAuthenticationResponse;

    nativeModule.get.mockResolvedValue(invalidAuthenticationResponse);

    await expect(
      moduleExports.authenticateWithPasskey(authenticationOptions())
    ).rejects.toMatchObject({
      code: "ERR_PASSKEY_INVALID_RESPONSE",
    });
  });

  it("reports invalid authentication options as validation errors", async () => {
    const invalidOptions = {
      ...authenticationOptions(),
      allowCredentials: [{ id: "", type: "public-key" }],
    } as unknown as PublicKeyCredentialRequestOptionsJSON;

    await expect(
      moduleExports.authenticateWithPasskey(invalidOptions)
    ).rejects.toMatchObject({
      code: "ERR_PASSKEY_VALIDATION",
    });
    expect(nativeModule.get).not.toHaveBeenCalled();
  });

  it("keeps deprecated get alias wired to authenticateWithPasskey", async () => {
    nativeModule.get.mockResolvedValue(authenticationResponse());

    await moduleExports.get(authenticationOptions());

    expect(nativeModule.get).toHaveBeenCalledTimes(1);
  });

  it("forwards Rust helper bridge methods", async () => {
    nativeModule.normalizeChallenge.mockResolvedValue("Y2hhbGxlbmdl");
    nativeModule.validateRelyingPartyId.mockResolvedValue("example.com");
    nativeModule.describeCeremony.mockResolvedValue({
      challenge: "Y2hhbGxlbmdl",
      clientDataType: "webauthn.create",
      kind: "create",
      origin: "https://example.com",
      rpId: "example.com",
    });

    await expect(
      moduleExports.normalizeChallenge("Y2hhbGxlbmdl==")
    ).resolves.toBe("Y2hhbGxlbmdl");
    await expect(
      moduleExports.validateRelyingPartyId("Example.COM")
    ).resolves.toBe("example.com");
    await expect(
      moduleExports.describeCeremony(
        "create",
        "Y2hhbGxlbmdl",
        "example.com",
        "https://example.com"
      )
    ).resolves.toMatchObject({
      clientDataType: "webauthn.create",
      rpId: "example.com",
    });
  });

  it("exports the public error class", () => {
    expect(new moduleExports.PasskeyError("message", "ERR_TEST")).toMatchObject(
      {
        code: "ERR_TEST",
        message: "message",
      }
    );
  });
});
