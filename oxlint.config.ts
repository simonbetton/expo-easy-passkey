import { defineConfig } from "oxlint";
import core from "ultracite/oxlint/core";
import jest from "ultracite/oxlint/jest";
import next from "ultracite/oxlint/next";
import react from "ultracite/oxlint/react";

export default defineConfig({
  ...core,
  plugins: [
    ...(core.plugins ?? []),
    ...(react.plugins ?? []),
    ...(next.plugins ?? []),
    ...(jest.plugins ?? []),
  ],
  rules: {
    ...core.rules,
    ...react.rules,
    ...next.rules,
    ...jest.rules,
    "unicorn/filename-case": "off",
  },
});
