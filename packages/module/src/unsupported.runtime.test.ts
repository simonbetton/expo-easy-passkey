import { spawnSync } from "node:child_process";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";

const require = createRequire(import.meta.url);
const moduleRoot = path.join(import.meta.dirname, "..");
const packageJson = require("../package.json") as {
  name: string;
  version: string;
};

const registrationOptions = {
  challenge: "Y2hhbGxlbmdl",
  pubKeyCredParams: [{ alg: -7, type: "public-key" }],
  rp: { id: "example.com", name: "Example" },
  user: {
    displayName: "Demo User",
    id: "dXNlcg",
    name: "demo@example.com",
  },
};

const authenticationOptions = {
  challenge: "YXV0aA",
  rpId: "example.com",
};

const probeScript = String.raw`
const fs = require("node:fs");

const reportPath = process.argv[2];
const optionsPath = process.argv[3];
const options = JSON.parse(fs.readFileSync(optionsPath, "utf8"));

const run = async () => {
  const imported = await import("expo-easy-passkey");
  const availability = imported.getPasskeyAvailability();
  const report = {
    availability,
    platform: imported.getPlatform(),
    supported: imported.isSupported(),
    create: null,
    authenticate: null,
  };

  try {
    await imported.createPasskey(options.registration);
    report.create = { ok: true };
  } catch (error) {
    report.create = {
      ok: false,
      name: error?.name ?? null,
      code: error?.code ?? null,
      message: error?.message ?? String(error),
    };
  }

  try {
    await imported.authenticateWithPasskey(options.authentication);
    report.authenticate = { ok: true };
  } catch (error) {
    report.authenticate = {
      ok: false,
      name: error?.name ?? null,
      code: error?.code ?? null,
      message: error?.message ?? String(error),
    };
  }

  fs.writeFileSync(reportPath, JSON.stringify(report));
};

run().catch((error) => {
  fs.writeFileSync(
    reportPath,
    JSON.stringify({
      importFailed: true,
      name: error?.name ?? null,
      message: error?.message ?? String(error),
      stack: error?.stack ?? null,
    })
  );
  process.exitCode = 1;
});
`;

interface CeremonyReport {
  ok: boolean;
  name?: string | null;
  code?: string | null;
  message?: string | null;
}

interface ProbeReport {
  importFailed?: boolean;
  name?: string | null;
  message?: string | null;
  stack?: string | null;
  availability?: { supported: boolean; platform: string };
  platform?: string;
  supported?: boolean;
  create?: CeremonyReport | null;
  authenticate?: CeremonyReport | null;
}

describe("unsupported runtime package contract", () => {
  let workspaceRoot = "";

  beforeAll(() => {
    workspaceRoot = mkdtempSync(
      path.join(tmpdir(), "expo-easy-passkey-unsupported-")
    );
    const build = spawnSync("pnpm", ["build"], {
      cwd: moduleRoot,
      encoding: "utf-8",
    });
    expect(build.status).toBe(0);

    const pack = spawnSync("npm", ["pack", "--json"], {
      cwd: moduleRoot,
      encoding: "utf-8",
    });
    expect(pack.status).toBe(0);
    const packed = JSON.parse(pack.stdout) as { filename: string }[];
    const tarballName = packed[0]?.filename;
    expect(tarballName).toEqual(expect.any(String));
    if (!tarballName) {
      throw new Error("npm pack did not report a tarball filename");
    }
    const tarballPath = path.join(moduleRoot, tarballName);
    const installRoot = path.join(workspaceRoot, "consumer");
    mkdirSync(installRoot, { recursive: true });
    writeFileSync(
      path.join(installRoot, "package.json"),
      JSON.stringify(
        {
          name: "expo-easy-passkey-unsupported-consumer",
          private: true,
          type: "module",
        },
        null,
        2
      )
    );

    const install = spawnSync("npm", ["install", tarballPath], {
      cwd: installRoot,
      encoding: "utf-8",
    });
    expect(install.status).toBe(0);
    expect(packageJson.name).toBe("expo-easy-passkey");
    rmSync(tarballPath, { force: true });
  }, 120_000);

  afterAll(() => {
    if (workspaceRoot) {
      rmSync(workspaceRoot, { force: true, recursive: true });
    }
  });

  const runProbe = (args: {
    conditions: string[];
    preload?: string;
  }): ProbeReport => {
    const consumerRoot = path.join(workspaceRoot, "consumer");
    const reportPath = path.join(
      consumerRoot,
      `report-${Date.now()}-${Math.random()}.json`
    );
    const optionsPath = path.join(consumerRoot, "ceremony-options.json");
    const scriptPath = path.join(consumerRoot, "probe.cjs");
    writeFileSync(
      optionsPath,
      JSON.stringify({
        authentication: authenticationOptions,
        registration: registrationOptions,
      })
    );
    writeFileSync(scriptPath, probeScript);

    const nodeArgs = [
      ...args.conditions.flatMap((condition) => ["--conditions", condition]),
      ...(args.preload ? ["--import", pathToFileURL(args.preload).href] : []),
      scriptPath,
      reportPath,
      optionsPath,
    ];
    const result = spawnSync(process.execPath, nodeArgs, {
      cwd: consumerRoot,
      encoding: "utf-8",
      env: process.env,
    });

    let report: ProbeReport;
    try {
      report = JSON.parse(readFileSync(reportPath, "utf-8")) as ProbeReport;
    } catch (error) {
      throw new Error(
        `probe did not write a report under conditions ${args.conditions.join(",") || "(default)"}: ${error instanceof Error ? error.message : String(error)}\nstatus:${result.status}\nstdout:${result.stdout}\nstderr:${result.stderr}`,
        { cause: error }
      );
    }

    if (report.importFailed) {
      throw new Error(
        `import failed under conditions ${args.conditions.join(",") || "(default)"}: ${report.message}\n${report.stack ?? ""}\nstdout:${result.stdout}\nstderr:${result.stderr}`
      );
    }

    return report;
  };

  it("imports in an SSR environment without native modules or browser globals", () => {
    expect(typeof document).toBe("undefined");
    expect(typeof window).toBe("undefined");

    const report = runProbe({ conditions: [] });

    expect(report.availability).toEqual({
      platform: "web",
      supported: false,
    });
    expect(report.platform).toBe("web");
    expect(report.supported).toBe(false);
    expect(report.create).toMatchObject({
      code: "ERR_PASSKEY_UNSUPPORTED",
      name: "PasskeyError",
      ok: false,
    });
    expect(report.authenticate).toMatchObject({
      code: "ERR_PASSKEY_UNSUPPORTED",
      name: "PasskeyError",
      ok: false,
    });
    expect(report.create?.message).toMatch(/web/iu);
    expect(report.create?.message).toMatch(/future/iu);
  });

  it("imports in a browser-like environment with the web unsupported contract", () => {
    const report = runProbe({ conditions: ["browser"] });

    expect(report.availability).toEqual({
      platform: "web",
      supported: false,
    });
    expect(report.create).toMatchObject({
      code: "ERR_PASSKEY_UNSUPPORTED",
      ok: false,
    });
    expect(report.authenticate).toMatchObject({
      code: "ERR_PASSKEY_UNSUPPORTED",
      ok: false,
    });
  });

  it("fails at ceremony invocation when the native module is missing", () => {
    const mockPath = path.join(workspaceRoot, "expo-modules-core-mock.mjs");
    const loaderPath = path.join(workspaceRoot, "missing-native-loader.mjs");
    const preloadPath = path.join(workspaceRoot, "register-missing-native.mjs");

    writeFileSync(
      mockPath,
      String.raw`
export const Platform = { OS: "ios" };
export const requireOptionalNativeModule = () => null;
export const requireNativeModule = (moduleName) => {
  throw new Error("Cannot find native module '" + moduleName + "'");
};
`
    );
    writeFileSync(
      loaderPath,
      String.raw`
import { pathToFileURL } from "node:url";

export async function resolve(specifier, context, nextResolve) {
  if (specifier === "expo-modules-core") {
    return {
      shortCircuit: true,
      url: pathToFileURL(${JSON.stringify(mockPath)}).href,
    };
  }

  return nextResolve(specifier, context);
}
`
    );
    writeFileSync(
      preloadPath,
      String.raw`
import { register } from "node:module";
import { pathToFileURL } from "node:url";

register(pathToFileURL(${JSON.stringify(loaderPath)}).href);
`
    );

    const report = runProbe({
      conditions: ["react-native"],
      preload: preloadPath,
    });

    expect(report.availability).toEqual({
      platform: "ios",
      supported: false,
    });
    expect(report.create).toMatchObject({
      code: "ERR_PASSKEY_UNSUPPORTED",
      name: "PasskeyError",
      ok: false,
    });
    expect(report.authenticate).toMatchObject({
      code: "ERR_PASSKEY_UNSUPPORTED",
      name: "PasskeyError",
      ok: false,
    });
    expect(report.create?.message).toMatch(/development build|Expo Go/iu);
  });
});
