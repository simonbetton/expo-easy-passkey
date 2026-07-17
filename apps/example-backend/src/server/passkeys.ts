import "./env.js";
import {
  generateAuthenticationOptions,
  generateRegistrationOptions,
  verifyAuthenticationResponse,
  verifyRegistrationResponse,
} from "@simplewebauthn/server";
import type {
  AuthenticationResponseJSON,
  RegistrationResponseJSON,
} from "@simplewebauthn/server";
import { isoUint8Array } from "@simplewebauthn/server/helpers";

import { relyingParty } from "./config.js";
import { demoStore } from "./store.js";
import type { DemoStore } from "./store.js";

const supportedAlgorithmIDs = [-7, -257];

const demoSession = (credentialId: string) => ({
  credentialId,
  expiresInSeconds: 3600,
  token: "demo-session-token",
});

export interface CeremonyVerificationRequest<Response> {
  ceremonyId: string;
  response: Response;
}

export interface PasskeyDependencies {
  generateAuthenticationOptions: typeof generateAuthenticationOptions;
  generateRegistrationOptions: typeof generateRegistrationOptions;
  verifyAuthenticationResponse: typeof verifyAuthenticationResponse;
  verifyRegistrationResponse: typeof verifyRegistrationResponse;
}

const defaultDependencies: PasskeyDependencies = {
  generateAuthenticationOptions,
  generateRegistrationOptions,
  verifyAuthenticationResponse,
  verifyRegistrationResponse,
};

export const createPasskeyService = (
  store: DemoStore,
  dependencies: PasskeyDependencies = defaultDependencies
) => {
  const getRegistrationOptions = async () => {
    const user = store.getUser();
    const options = await dependencies.generateRegistrationOptions({
      attestationType: "none",
      authenticatorSelection: {
        authenticatorAttachment: "platform",
        residentKey: "preferred",
        userVerification: "preferred",
      },
      excludeCredentials: store.getUserPasskeys().map((passkey) => ({
        id: passkey.credentialId,
        transports: passkey.transports,
      })),
      rpID: relyingParty.rpId,
      rpName: relyingParty.rpName,
      supportedAlgorithmIDs,
      timeout: 60_000,
      userDisplayName: user.displayName,
      userID: isoUint8Array.fromUTF8String(user.webAuthnUserId),
      userName: user.email,
    });
    const ceremonyId = store.createCeremony(
      "registration",
      user.id,
      options.challenge,
      relyingParty.challengeTtlMs
    );

    return {
      ceremonyId,
      options: {
        ...options,
        origin: relyingParty.origin,
      },
    };
  };

  const verifyRegistration = async ({
    ceremonyId,
    response,
  }: CeremonyVerificationRequest<RegistrationResponseJSON>) => {
    const user = store.getUser();
    const ceremony = {
      ceremonyId,
      kind: "registration" as const,
      userId: user.id,
    };
    const expectedChallenge = store.getCeremonyChallenge(ceremony);
    const verification = await dependencies.verifyRegistrationResponse({
      expectedChallenge,
      expectedOrigin: relyingParty.origin,
      expectedRPID: relyingParty.rpId,
      response,
    });

    if (!(verification.verified && verification.registrationInfo)) {
      throw new Error("Passkey registration failed.");
    }

    store.consumeCeremony(ceremony, expectedChallenge);

    const { credential, credentialBackedUp, credentialDeviceType } =
      verification.registrationInfo;

    store.savePasskey({
      backedUp: credentialBackedUp,
      counter: credential.counter,
      credentialId: credential.id,
      deviceType: credentialDeviceType,
      publicKey: credential.publicKey,
      transports: credential.transports,
      userId: user.id,
      webAuthnUserId: Buffer.from(user.webAuthnUserId, "utf-8").toString(
        "base64url"
      ),
    });

    return {
      credentialId: credential.id,
      verified: true as const,
    };
  };

  const getAuthenticationOptions = async () => {
    const user = store.getUser();
    const options = await dependencies.generateAuthenticationOptions({
      rpID: relyingParty.rpId,
      timeout: 60_000,
      userVerification: "preferred",
    });
    const ceremonyId = store.createCeremony(
      "authentication",
      user.id,
      options.challenge,
      relyingParty.challengeTtlMs
    );

    return {
      ceremonyId,
      options: {
        ...options,
        origin: relyingParty.origin,
      },
    };
  };

  const verifyAuthentication = async ({
    ceremonyId,
    response,
  }: CeremonyVerificationRequest<AuthenticationResponseJSON>) => {
    const user = store.getUser();
    const passkey = store.getPasskey(response.id);

    if (!passkey) {
      throw new Error("Passkey credential was not found.");
    }

    const ceremony = {
      ceremonyId,
      kind: "authentication" as const,
      userId: user.id,
    };
    const expectedChallenge = store.getCeremonyChallenge(ceremony);
    const verification = await dependencies.verifyAuthenticationResponse({
      credential: {
        counter: passkey.counter,
        id: passkey.credentialId,
        publicKey: Uint8Array.from(passkey.publicKey),
        transports: passkey.transports,
      },
      expectedChallenge,
      expectedOrigin: relyingParty.origin,
      expectedRPID: relyingParty.rpId,
      response,
    });

    if (!verification.verified) {
      throw new Error("Passkey authentication failed.");
    }

    store.consumeCeremony(ceremony, expectedChallenge);
    store.updatePasskeyCounter(
      passkey.credentialId,
      verification.authenticationInfo.newCounter
    );

    return {
      session: demoSession(passkey.credentialId),
      verified: true as const,
    };
  };

  return {
    getAuthenticationOptions,
    getRegistrationOptions,
    verifyAuthentication,
    verifyRegistration,
  };
};

export const {
  getAuthenticationOptions,
  getRegistrationOptions,
  verifyAuthentication,
  verifyRegistration,
} = createPasskeyService(demoStore);
