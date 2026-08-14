import { describe, expect, it } from "@jest/globals";

import app from "./index.js";

const postJson = (path: string, body: unknown): Promise<Response> =>
  app.handle(
    new Request(`https://example.com${path}`, {
      body: JSON.stringify(body),
      headers: { "content-type": "application/json" },
      method: "POST",
    })
  );

describe("example backend HTTP verification", () => {
  it("keeps CORS usable for the Expo app", async () => {
    const response = await app.handle(
      new Request("https://example.com/passkeys/register/verify", {
        method: "OPTIONS",
      })
    );

    expect(response.status).toBe(204);
    expect(response.headers.get("access-control-allow-origin")).toBe("*");
  });

  it("rejects a missing ceremonyId with a stable error", async () => {
    const response = await postJson("/passkeys/register/verify", {
      response: {
        id: "Y3JlZA",
        rawId: "Y3JlZA",
        response: {},
        type: "public-key",
      },
    });
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body).toEqual({ error: "Invalid request." });
  });

  it("rejects a non-object response with a stable error", async () => {
    const response = await postJson("/passkeys/authenticate/verify", {
      ceremonyId: "ceremony-id",
      response: "not-an-object",
    });
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body).toEqual({ error: "Invalid request." });
  });

  it("does not leak library internals for unknown errors", async () => {
    const response = await postJson("/passkeys/register/verify", {
      ceremonyId: "missing-ceremony",
      response: {
        id: "Y3JlZA",
        rawId: "Y3JlZA",
        response: {},
        type: "public-key",
      },
    });
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body).toEqual({
      error: "No matching passkey ceremony is pending.",
    });
    expect(JSON.stringify(body)).not.toMatch(/stack|simplewebauthn|elysia/iu);
  });
});
