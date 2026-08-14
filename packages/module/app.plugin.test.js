// @ts-check

import withExpoEasyPasskey from "./app.plugin.js";

describe("withExpoEasyPasskey", () => {
  it("adds iOS webcredentials domains without creating Android app links", () => {
    const existingIntentFilter = {
      action: "VIEW",
      data: [{ scheme: "myapp" }],
    };
    /** @type {import("./app.plugin.js").ExpoEasyPasskeyConfig} */
    const config = {
      android: {
        intentFilters: [existingIntentFilter],
      },
      ios: {
        associatedDomains: ["webcredentials:existing.example.com"],
      },
    };

    const result = withExpoEasyPasskey(config, {
      associatedDomains: ["webcredentials:extra.example.com"],
      domains: ["example.com", "webcredentials:login.example.com"],
    });

    expect(result.ios?.associatedDomains).toEqual([
      "webcredentials:existing.example.com",
      "webcredentials:extra.example.com",
      "webcredentials:example.com",
      "webcredentials:login.example.com",
    ]);
    expect(result.android).toEqual({
      intentFilters: [existingIntentFilter],
    });
  });

  it("does not add Android config for passkey-only domains", () => {
    const result = withExpoEasyPasskey({}, { domains: ["example.com"] });

    expect(result).toEqual({
      ios: {
        associatedDomains: ["webcredentials:example.com"],
      },
    });
  });

  it("accepts a bare relying-party hostname", () => {
    const result = withExpoEasyPasskey({}, { domains: ["example.com"] });

    expect(result.ios?.associatedDomains).toEqual([
      "webcredentials:example.com",
    ]);
  });

  it("accepts already-prefixed webcredentials entries", () => {
    const result = withExpoEasyPasskey(
      {},
      { domains: ["webcredentials:login.example.com"] }
    );

    expect(result.ios?.associatedDomains).toEqual([
      "webcredentials:login.example.com",
    ]);
  });

  it("ignores empty and whitespace-only domains", () => {
    const result = withExpoEasyPasskey(
      {},
      { domains: ["example.com", "", "   ", "\t"] }
    );

    expect(result.ios?.associatedDomains).toEqual([
      "webcredentials:example.com",
    ]);
  });

  it.each([
    ["https://example.com"],
    ["example.com/login"],
    ["example.com:443"],
    ["user@example.com"],
    ["example.com?mode=developer"],
  ])("rejects invalid domain %s during prebuild", (domain) => {
    expect(() => withExpoEasyPasskey({}, { domains: [domain] })).toThrow(
      `Invalid Expo Easy Passkey plugin domain "${domain}": Relying Party domains must be hostnames without scheme, path, or port.`
    );
  });
});
