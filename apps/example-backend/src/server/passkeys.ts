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

const supportedAlgorithmIDs = [-7, -257];

const demoSession = (credentialId: string) => ({
  credentialId,
  expiresInSeconds: 3600,
  token: "demo-session-token",
});

export const getRegistrationOptions = async () => {
  const user = demoStore.getUser();
  const options = await generateRegistrationOptions({
    attestationType: "none",
    authenticatorSelection: {
      authenticatorAttachment: "platform",
      residentKey: "preferred",
      userVerification: "preferred",
    },
    excludeCredentials: demoStore.getUserPasskeys().map((passkey) => ({
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

  demoStore.saveChallenge(
    "registration",
    user.id,
    options.challenge,
    relyingParty.challengeTtlMs
  );

  return {
    ...options,
    origin: relyingParty.origin,
  };
};

export const verifyRegistration = async (
  response: RegistrationResponseJSON
) => {
  const user = demoStore.getUser();
  const expectedChallenge = demoStore.consumeChallenge("registration", user.id);
  const verification = await verifyRegistrationResponse({
    expectedChallenge,
    expectedOrigin: relyingParty.origin,
    expectedRPID: relyingParty.rpId,
    response,
  });

  if (!(verification.verified && verification.registrationInfo)) {
    throw new Error("Passkey registration failed.");
  }

  const { credential, credentialBackedUp, credentialDeviceType } =
    verification.registrationInfo;

  demoStore.savePasskey({
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
    verified: true,
  };
};

export const getAuthenticationOptions = async () => {
  const user = demoStore.getUser();
  const options = await generateAuthenticationOptions({
    rpID: relyingParty.rpId,
    timeout: 60_000,
    userVerification: "preferred",
  });

  demoStore.saveChallenge(
    "authentication",
    user.id,
    options.challenge,
    relyingParty.challengeTtlMs
  );

  return {
    ...options,
    origin: relyingParty.origin,
  };
};

export const verifyAuthentication = async (
  response: AuthenticationResponseJSON
) => {
  const user = demoStore.getUser();
  const passkey = demoStore.getPasskey(response.id);

  if (!passkey) {
    throw new Error("Passkey credential was not found.");
  }

  const expectedChallenge = demoStore.consumeChallenge(
    "authentication",
    user.id
  );
  const verification = await verifyAuthenticationResponse({
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

  demoStore.updatePasskeyCounter(
    passkey.credentialId,
    verification.authenticationInfo.newCounter
  );

  return {
    session: demoSession(passkey.credentialId),
    verified: true,
  };
};
