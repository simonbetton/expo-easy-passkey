import { describe, expect, it, jest } from "@jest/globals";
import type {
  AuthenticationResponseJSON,
  RegistrationResponseJSON,
} from "@simplewebauthn/server";

import { relyingParty } from "./config.js";
import { createPasskeyService } from "./passkeys.js";
import type { PasskeyDependencies } from "./passkeys.js";
import { createDemoStore } from "./store.js";

const registrationResponse = (id: string) =>
  ({ id }) as RegistrationResponseJSON;

const authenticationResponse = (id: string) =>
  ({ id }) as AuthenticationResponseJSON;

const registrationVerification = (credentialId: string) =>
  ({
    registrationInfo: {
      credential: {
        counter: 0,
        id: credentialId,
        publicKey: new Uint8Array([1, 2, 3]),
        transports: ["internal"],
      },
      credentialBackedUp: false,
      credentialDeviceType: "singleDevice",
    },
    verified: true,
  }) as never;

const authenticationVerification = {
  authenticationInfo: { newCounter: 1 },
  verified: true,
} as never;

describe("passkey ceremony service", () => {
  it.each([
    ["registration then authentication", ["registration", "authentication"]],
    ["authentication then registration", ["authentication", "registration"]],
  ] as const)(
    "completes overlapping ceremonies: %s",
    async (_case, completionOrder) => {
      const ceremonyIds = ["registration-id", "authentication-id"];
      const store = createDemoStore({
        createCeremonyId: () => ceremonyIds.shift() ?? "unexpected-id",
      });
      store.savePasskey({
        backedUp: false,
        counter: 0,
        credentialId: "existing-credential",
        deviceType: "singleDevice",
        publicKey: new Uint8Array([1, 2, 3]),
        transports: ["internal"],
        userId: store.getUser().id,
        webAuthnUserId: "demo-user",
      });
      const dependencies = {
        generateAuthenticationOptions: jest.fn(
          (
            _options: Parameters<
              PasskeyDependencies["generateAuthenticationOptions"]
            >[0]
          ) =>
            Promise.resolve({
              challenge: "authentication-challenge",
            })
        ),
        generateRegistrationOptions: jest.fn(
          (
            _options: Parameters<
              PasskeyDependencies["generateRegistrationOptions"]
            >[0]
          ) =>
            Promise.resolve({
              challenge: "registration-challenge",
            })
        ),
        verifyAuthenticationResponse: jest.fn(
          (
            _options: Parameters<
              PasskeyDependencies["verifyAuthenticationResponse"]
            >[0]
          ) => Promise.resolve(authenticationVerification)
        ),
        verifyRegistrationResponse: jest.fn(
          (
            _options: Parameters<
              PasskeyDependencies["verifyRegistrationResponse"]
            >[0]
          ) => Promise.resolve(registrationVerification("new-credential"))
        ),
      };
      const service = createPasskeyService(store, dependencies as never);
      const registration = await service.getRegistrationOptions();
      const authentication = await service.getAuthenticationOptions();

      const completions = {
        authentication: () =>
          service.verifyAuthentication({
            ceremonyId: authentication.ceremonyId,
            response: authenticationResponse("existing-credential"),
          }),
        registration: () =>
          service.verifyRegistration({
            ceremonyId: registration.ceremonyId,
            response: registrationResponse("new-credential"),
          }),
      };

      await expect(completions[completionOrder[0]]()).resolves.toMatchObject({
        verified: true,
      });
      await expect(completions[completionOrder[1]]()).resolves.toMatchObject({
        verified: true,
      });

      expect(
        dependencies.verifyRegistrationResponse.mock.calls[0]?.[0]
      ).toEqual(
        expect.objectContaining({
          expectedChallenge: "registration-challenge",
          expectedOrigin: relyingParty.expectedOrigins,
        })
      );
      expect(
        dependencies.verifyAuthenticationResponse.mock.calls[0]?.[0]
      ).toEqual(
        expect.objectContaining({
          expectedChallenge: "authentication-challenge",
          expectedOrigin: relyingParty.expectedOrigins,
        })
      );
    }
  );

  it("leaves ceremonies available when a different client's response fails", async () => {
    const ceremonyIds = ["first-id", "second-id"];
    const store = createDemoStore({
      createCeremonyId: () => ceremonyIds.shift() ?? "unexpected-id",
    });
    const responseChallenges = new Map([
      ["first-client", "first-challenge"],
      ["second-client", "second-challenge"],
    ]);
    const dependencies = {
      generateAuthenticationOptions: jest.fn(),
      generateRegistrationOptions: jest
        .fn()
        .mockResolvedValueOnce({ challenge: "first-challenge" } as never)
        .mockResolvedValueOnce({ challenge: "second-challenge" } as never),
      verifyAuthenticationResponse: jest.fn(),
      verifyRegistrationResponse: jest.fn(
        ({
          expectedChallenge,
          response,
        }: {
          expectedChallenge: string;
          response: RegistrationResponseJSON;
        }) => {
          const responseId = response.id;
          if (responseChallenges.get(responseId) !== expectedChallenge) {
            throw new Error("Passkey response challenge did not match.");
          }
          return Promise.resolve(registrationVerification(responseId));
        }
      ),
    };
    const service = createPasskeyService(store, dependencies as never);
    const first = await service.getRegistrationOptions();
    const second = await service.getRegistrationOptions();

    await expect(
      service.verifyRegistration({
        ceremonyId: second.ceremonyId,
        response: registrationResponse("first-client"),
      })
    ).rejects.toThrow("Passkey response challenge did not match.");

    await expect(
      service.verifyRegistration({
        ceremonyId: first.ceremonyId,
        response: registrationResponse("first-client"),
      })
    ).resolves.toMatchObject({ verified: true });
    await expect(
      service.verifyRegistration({
        ceremonyId: second.ceremonyId,
        response: registrationResponse("second-client"),
      })
    ).resolves.toMatchObject({ verified: true });
  });

  it("allows only one concurrent verification to consume a ceremony", async () => {
    const store = createDemoStore({
      createCeremonyId: () => "registration-id",
    });
    const dependencies = {
      generateAuthenticationOptions: jest.fn(),
      generateRegistrationOptions: jest.fn(() =>
        Promise.resolve({
          challenge: "registration-challenge",
        })
      ),
      verifyAuthenticationResponse: jest.fn(),
      verifyRegistrationResponse: jest.fn(() =>
        Promise.resolve(registrationVerification("new-credential"))
      ),
    };
    const service = createPasskeyService(store, dependencies as never);
    const registration = await service.getRegistrationOptions();
    const request = {
      ceremonyId: registration.ceremonyId,
      response: registrationResponse("new-credential"),
    };

    const results = await Promise.allSettled([
      service.verifyRegistration(request),
      service.verifyRegistration(request),
    ]);

    expect(results.filter(({ status }) => status === "fulfilled")).toHaveLength(
      1
    );
    expect(results.filter(({ status }) => status === "rejected")).toHaveLength(
      1
    );
  });
});
