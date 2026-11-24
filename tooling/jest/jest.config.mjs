/** @type {import("jest").Config} */
export default {
  clearMocks: true,
  collectCoverageFrom: ["src/**/*.{ts,tsx}", "!src/**/*.d.ts"],
  extensionsToTreatAsEsm: [".ts", ".tsx"],
  moduleFileExtensions: ["ts", "tsx", "js", "jsx", "json"],
  moduleNameMapper: {
    "^(\\.{1,2}/.*)\\.js$": "$1",
  },
  testEnvironment: "node",
  testMatch: ["<rootDir>/src/**/*.test.ts"],
  // Jest uses Node's built-in type stripping for these ESM tests.
  transform: {},
};
