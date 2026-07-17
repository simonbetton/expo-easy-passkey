const defaultRpId = "expo-easy-passkey-example-backend.vercel.app";
const defaultAndroidSha256Fingerprint =
  "FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C";
const sha256FingerprintPattern = /^(?:[A-Fa-f0-9]{2}:){31}[A-Fa-f0-9]{2}$/u;

type ServerEnvironment = Record<string, string | undefined>;

const getPositiveNumber = (
  value: string | undefined,
  fallback: number
): number => {
  if (!value) {
    return fallback;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const getExactHttpsOrigin = (value: string): string => {
  try {
    const parsed = new URL(value);

    if (parsed.protocol === "https:" && parsed.origin === value) {
      return value;
    }
  } catch {
    // The common error below keeps startup diagnostics configuration-specific.
  }

  throw new Error("PASSKEY_ORIGIN must be an exact HTTPS origin.");
};

const getAndroidFingerprints = (value: string): string[] =>
  value
    .split(",")
    .map((fingerprint) => fingerprint.trim())
    .map((fingerprint) => {
      if (!sha256FingerprintPattern.test(fingerprint)) {
        throw new Error(
          `Invalid Android SHA-256 certificate fingerprint: ${fingerprint || "(empty)"}`
        );
      }

      return fingerprint.toUpperCase();
    });

const androidOrigin = (fingerprint: string): string =>
  `android:apk-key-hash:${Buffer.from(
    fingerprint.replaceAll(":", ""),
    "hex"
  ).toString("base64url")}`;

export const createServerConfig = (environment: ServerEnvironment) => {
  const rpId = environment.PASSKEY_RP_ID ?? defaultRpId;
  const origin = getExactHttpsOrigin(
    environment.PASSKEY_ORIGIN ?? `https://${rpId}`
  );
  const androidSha256CertFingerprints = Object.freeze(
    getAndroidFingerprints(
      environment.ANDROID_SHA256_CERT_FINGERPRINTS ??
        defaultAndroidSha256Fingerprint
    )
  );
  const appTrust = {
    androidPackageName:
      environment.ANDROID_PACKAGE_NAME ??
      "dev.simonbetton.expoeasypasskey.example",
    androidSha256CertFingerprints,
    appleAppId:
      environment.APPLE_APP_ID ??
      `${environment.APPLE_TEAM_ID ?? "DA982D649A"}.${
        environment.IOS_BUNDLE_IDENTIFIER ??
        "dev.simonbetton.expoeasypasskey.example"
      }`,
  };
  const relyingParty = {
    challengeTtlMs: getPositiveNumber(
      environment.PASSKEY_CHALLENGE_TTL_MS,
      300_000
    ),
    expectedOrigins: Object.freeze([
      origin,
      ...androidSha256CertFingerprints.map(androidOrigin),
    ]),
    origin,
    rpId,
    rpName: environment.PASSKEY_RP_NAME ?? "Expo Easy Passkey",
  };

  return { appTrust, relyingParty };
};

export const { appTrust, relyingParty } = createServerConfig(process.env);
