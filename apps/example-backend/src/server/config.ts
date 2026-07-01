const defaultRpId = "expo-easy-passkey-example-backend.vercel.app";
const defaultAndroidSha256Fingerprint =
  "FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C";

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

export const relyingParty = {
  challengeTtlMs: getPositiveNumber(
    process.env.PASSKEY_CHALLENGE_TTL_MS,
    300_000
  ),
  origin:
    process.env.PASSKEY_ORIGIN ??
    `https://${process.env.PASSKEY_RP_ID ?? defaultRpId}`,
  rpId: process.env.PASSKEY_RP_ID ?? defaultRpId,
  rpName: process.env.PASSKEY_RP_NAME ?? "Expo Easy Passkey",
};

export const appTrust = {
  androidPackageName:
    process.env.ANDROID_PACKAGE_NAME ??
    "dev.simonbetton.expoeasypasskey.example",
  androidSha256CertFingerprints: (
    process.env.ANDROID_SHA256_CERT_FINGERPRINTS ??
    defaultAndroidSha256Fingerprint
  )
    .split(",")
    .map((fingerprint) => fingerprint.trim())
    .filter((fingerprint) => fingerprint.length > 0),
  appleAppId:
    process.env.APPLE_APP_ID ??
    `${process.env.APPLE_TEAM_ID ?? "DA982D649A"}.${
      process.env.IOS_BUNDLE_IDENTIFIER ??
      "dev.simonbetton.expoeasypasskey.example"
    }`,
};
