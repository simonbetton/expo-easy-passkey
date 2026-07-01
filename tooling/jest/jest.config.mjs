/** @type {import("jest").Config} */
export default {
  clearMocks: true,
  collectCoverageFrom: ["src/**/*.{ts,tsx}", "!src/**/*.d.ts"],
  extensionsToTreatAsEsm: [".ts", ".tsx"],
  moduleFileExtensions: ["ts", "tsx", "js", "jsx", "json"],
  moduleNameMapper: {
    "^(\\.{1,2}/.*)\\.js$": "$1",
  },
  preset: "ts-jest/presets/default-esm",
  testEnvironment: "node",
  testMatch: ["<rootDir>/src/**/*.test.ts"],
  transform: {
    "^.+\\.tsx?$": [
      "ts-jest",
      {
        tsconfig: "<rootDir>/tsconfig.json",
        useESM: true,
      },
    ],
  },
};
