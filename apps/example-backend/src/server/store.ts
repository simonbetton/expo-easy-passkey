import type {
  AuthenticatorTransportFuture,
  Base64URLString,
  CredentialDeviceType,
} from "@simplewebauthn/server";

export interface DemoUser {
  displayName: string;
  email: string;
  id: string;
  webAuthnUserId: string;
}

export interface StoredChallenge {
  challenge: string;
  expiresAt: number;
  kind: "authentication" | "registration";
  userId: string;
}

export interface StoredPasskey {
  backedUp: boolean;
  counter: number;
  credentialId: Base64URLString;
  deviceType: CredentialDeviceType;
  publicKey: Uint8Array;
  transports?: AuthenticatorTransportFuture[];
  userId: string;
  webAuthnUserId: Base64URLString;
}

const demoUser: DemoUser = {
  displayName: "Demo User",
  email: "demo@expo-easy-passkey.vercel.app",
  id: "demo-user",
  webAuthnUserId: "expo-easy-passkey-demo-user",
};

const challenges = new Map<string, StoredChallenge>();
const passkeys = new Map<Base64URLString, StoredPasskey>();

const challengeKey = (kind: StoredChallenge["kind"], userId: string): string =>
  `${kind}:${userId}`;

const getUserPasskeys = (userId: string): StoredPasskey[] =>
  [...passkeys.values()].filter((passkey) => passkey.userId === userId);

export const demoStore = {
  consumeChallenge(kind: StoredChallenge["kind"], userId: string): string {
    const key = challengeKey(kind, userId);
    const stored = challenges.get(key);
    challenges.delete(key);

    if (!stored) {
      throw new Error("No passkey challenge is pending.");
    }

    if (stored.expiresAt <= Date.now()) {
      throw new Error("The passkey challenge expired.");
    }

    return stored.challenge;
  },

  getPasskey(credentialId: string): StoredPasskey | undefined {
    return passkeys.get(credentialId);
  },

  getUser(): DemoUser {
    return demoUser;
  },

  getUserPasskeys(): StoredPasskey[] {
    return getUserPasskeys(demoUser.id);
  },

  saveChallenge(
    kind: StoredChallenge["kind"],
    userId: string,
    challenge: string,
    ttlMs: number
  ): void {
    challenges.set(challengeKey(kind, userId), {
      challenge,
      expiresAt: Date.now() + ttlMs,
      kind,
      userId,
    });
  },

  savePasskey(passkey: StoredPasskey): void {
    passkeys.set(passkey.credentialId, passkey);
  },

  updatePasskeyCounter(credentialId: string, counter: number): void {
    const passkey = passkeys.get(credentialId);

    if (!passkey) {
      throw new Error("Passkey credential was not found.");
    }

    passkeys.set(credentialId, {
      ...passkey,
      counter,
    });
  },
};
