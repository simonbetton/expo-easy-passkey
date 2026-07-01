import "./server/env.js";
import type {
  AuthenticationResponseJSON,
  RegistrationResponseJSON,
} from "@simplewebauthn/server";
import { Elysia, t } from "elysia";

import { errorResponse, jsonResponse, emptyResponse } from "./server/http.js";
import {
  getAuthenticationOptions,
  getRegistrationOptions,
  verifyAuthentication,
  verifyRegistration,
} from "./server/passkeys.js";
import { androidAssetLinks, appleAppSiteAssociation } from "./server/trust.js";

const routes = [
  "/.well-known/apple-app-site-association",
  "/.well-known/assetlinks.json",
  "/passkeys/register/options",
  "/passkeys/register/verify",
  "/passkeys/authenticate/options",
  "/passkeys/authenticate/verify",
] as const;

const app = new Elysia()
  .get("/", () =>
    jsonResponse({
      name: "expo-easy-passkey example backend",
      routes,
    })
  )
  .get("/.well-known/apple-app-site-association", appleAppSiteAssociation)
  .get("/.well-known/assetlinks.json", androidAssetLinks)
  .options("/passkeys/register/options", emptyResponse)
  .options("/passkeys/register/verify", emptyResponse)
  .options("/passkeys/authenticate/options", emptyResponse)
  .options("/passkeys/authenticate/verify", emptyResponse)
  .post("/passkeys/register/options", async () => {
    try {
      return jsonResponse(await getRegistrationOptions());
    } catch (error) {
      return errorResponse(error);
    }
  })
  .post(
    "/passkeys/register/verify",
    async ({ body }) => {
      try {
        return jsonResponse(
          await verifyRegistration(body as RegistrationResponseJSON)
        );
      } catch (error) {
        return errorResponse(error);
      }
    },
    {
      body: t.Unknown(),
    }
  )
  .post("/passkeys/authenticate/options", async () => {
    try {
      return jsonResponse(await getAuthenticationOptions());
    } catch (error) {
      return errorResponse(error);
    }
  })
  .post(
    "/passkeys/authenticate/verify",
    async ({ body }) => {
      try {
        return jsonResponse(
          await verifyAuthentication(body as AuthenticationResponseJSON)
        );
      } catch (error) {
        return errorResponse(error);
      }
    },
    {
      body: t.Unknown(),
    }
  );

export type ExampleBackend = typeof app;

export default app;
