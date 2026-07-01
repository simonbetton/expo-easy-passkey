import baseConfig from "../../tooling/jest/jest.config.mjs";

/** @type {import("jest").Config} */
export default {
  ...baseConfig,
  displayName: "module",
  testMatch: [...baseConfig.testMatch, "<rootDir>/app.plugin.test.js"],
};
