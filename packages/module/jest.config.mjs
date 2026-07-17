import baseConfig from "../../tooling/jest/jest.config.mjs";

/** @type {import("jest").Config} */
export default {
  ...baseConfig,
  displayName: "module",
  moduleNameMapper: {
    ...baseConfig.moduleNameMapper,
    // Keep in-repo package imports on the native entry. Packed web/SSR
    // export conditions are covered by unsupported.runtime.test.ts.
    "^expo-easy-passkey$": "<rootDir>/src/index.ts",
  },
  testMatch: [...baseConfig.testMatch, "<rootDir>/app.plugin.test.js"],
};
