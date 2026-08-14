import { randomUUID } from "node:crypto";

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

export type CeremonyKind = "authentication" | "registration";

export interface CeremonyRef {
  ceremonyId: string;
  kind: CeremonyKind;
  userId: string;
}

export type CeremonyStatus = "pending" | "processing";

export interface StoredCeremony {
  challenge: string;
  ceremonyId: string;
  expiresAt: number;
  kind: CeremonyKind;
  status: CeremonyStatus;
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
  email: "demo@expo-easy-passkey-example-backend.vercel.app",
  id: "demo-user",
  webAuthnUserId: "expo-easy-passkey-demo-user",
};

interface DemoStoreOptions {
  createCeremonyId?: () => string;
  now?: () => number;
}

export const createDemoStore = ({
  createCeremonyId = randomUUID,
  now = Date.now,
}: DemoStoreOptions = {}) => {
  const ceremonies = new Map<string, StoredCeremony>();
  const passkeys = new Map<Base64URLString, StoredPasskey>();

  const purgeExpiredCeremonies = (currentTime: number): void => {
    for (const [ceremonyId, ceremony] of ceremonies) {
      if (ceremony.expiresAt <= currentTime) {
        ceremonies.delete(ceremonyId);
      }
    }
  };

  const getCeremony = ({
    ceremonyId,
    kind,
    userId,
  }: CeremonyRef): StoredCeremony => {
    const ceremony = ceremonies.get(ceremonyId);

    if (!ceremony) {
      throw new Error("No matching passkey ceremony is pending.");
    }

    if (ceremony.kind !== kind || ceremony.userId !== userId) {
      throw new Error("The passkey ceremony does not match this request.");
    }

    const currentTime = now();
    if (ceremony.expiresAt <= currentTime) {
      ceremonies.delete(ceremonyId);
      throw new Error("The passkey ceremony expired.");
    }

    purgeExpiredCeremonies(currentTime);
    return ceremony;
  };

  const getUserPasskeys = (userId: string): StoredPasskey[] =>
    [...passkeys.values()].filter((passkey) => passkey.userId === userId);

  return {
    /**
     * Atomically move a pending ceremony to processing. Only one claim can
     * succeed per ceremony ID. Failed verification should `releaseCeremony`
     * so a later retry can claim again; success should `consumeCeremony`.
     */
    claimCeremony(ceremony: CeremonyRef): string {
      const storedCeremony = getCeremony(ceremony);

      if (storedCeremony.status !== "pending") {
        throw new Error("No matching passkey ceremony is pending.");
      }

      ceremonies.set(ceremony.ceremonyId, {
        ...storedCeremony,
        status: "processing",
      });

      return storedCeremony.challenge;
    },

    consumeCeremony(ceremony: CeremonyRef, expectedChallenge: string): void {
      const storedCeremony = getCeremony(ceremony);

      if (storedCeremony.challenge !== expectedChallenge) {
        throw new Error("The passkey ceremony challenge does not match.");
      }

      ceremonies.delete(ceremony.ceremonyId);
    },

    createCeremony(
      kind: CeremonyKind,
      userId: string,
      challenge: string,
      ttlMs: number
    ): string {
      const currentTime = now();
      purgeExpiredCeremonies(currentTime);

      const ceremonyId = createCeremonyId();
      if (ceremonies.has(ceremonyId)) {
        throw new Error("The passkey ceremony identifier was not unique.");
      }

      ceremonies.set(ceremonyId, {
        ceremonyId,
        challenge,
        expiresAt: currentTime + ttlMs,
        kind,
        status: "pending",
        userId,
      });

      return ceremonyId;
    },

    getCeremonyChallenge(ceremony: CeremonyRef): string {
      return getCeremony(ceremony).challenge;
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

    releaseCeremony(ceremony: CeremonyRef): void {
      const storedCeremony = ceremonies.get(ceremony.ceremonyId);

      if (storedCeremony?.status !== "processing") {
        return;
      }

      ceremonies.set(ceremony.ceremonyId, {
        ...storedCeremony,
        status: "pending",
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
};

export type DemoStore = ReturnType<typeof createDemoStore>;

export const demoStore = createDemoStore();
