import { describe, expect, it } from "@jest/globals";

import { createServerConfig } from "./config.js";

const fingerprint = (start: number): string =>
  Array.from({ length: 32 }, (_, index) =>
    (start + index).toString(16).padStart(2, "0")
  )
    .join(":")
    .toUpperCase();

describe("relying-party origin configuration", () => {
  it("converts every trusted fingerprint to an exact Android origin", () => {
    const config = createServerConfig({
      ANDROID_SHA256_CERT_FINGERPRINTS: `${fingerprint(0)},${fingerprint(32)}`,
      PASSKEY_ORIGIN: "https://login.example.com",
      PASSKEY_RP_ID: "login.example.com",
    });

    expect(config.appTrust.androidSha256CertFingerprints).toEqual([
      fingerprint(0),
      fingerprint(32),
    ]);
    expect(config.relyingParty.expectedOrigins).toEqual([
      "https://login.example.com",
      "android:apk-key-hash:AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8",
      "android:apk-key-hash:ICEiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj8",
    ]);
    expect(Object.isFrozen(config.relyingParty.expectedOrigins)).toBe(true);
    expect(Object.isFrozen(config.appTrust.androidSha256CertFingerprints)).toBe(
      true
    );
  });

  it.each([
    ["too short", fingerprint(0).split(":").slice(0, 31).join(":")],
    ["invalid hex", `${fingerprint(0).slice(0, -2)}:GG`],
    ["missing separators", fingerprint(0).replaceAll(":", "")],
    ["empty", ""],
  ])("rejects a malformed %s fingerprint", (_case, configuredFingerprint) => {
    expect(() =>
      createServerConfig({
        ANDROID_SHA256_CERT_FINGERPRINTS: configuredFingerprint,
      })
    ).toThrow("Invalid Android SHA-256 certificate fingerprint");
  });

  it.each([
    "http://login.example.com",
    "https://login.example.com/path",
    "https://login.example.com/",
    "not-an-origin",
  ])("rejects malformed HTTPS origin %s", (origin) => {
    expect(() => createServerConfig({ PASSKEY_ORIGIN: origin })).toThrow(
      "PASSKEY_ORIGIN must be an exact HTTPS origin"
    );
  });
});
