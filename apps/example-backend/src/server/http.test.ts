import { describe, expect, it } from "@jest/globals";

import { errorResponse, publicErrorMessage } from "./http.js";

describe("public HTTP errors", () => {
  it("keeps known ceremony messages and hides implementation details", () => {
    expect(publicErrorMessage(new Error("Passkey registration failed."))).toBe(
      "Passkey registration failed."
    );
    expect(
      publicErrorMessage(new Error("Unexpected token } in JSON at position 12"))
    ).toBe("Passkey request failed.");
  });

  it("returns a stable JSON payload", async () => {
    const response = errorResponse(
      new TypeError("Cannot read properties of undefined")
    );
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body).toEqual({ error: "Passkey request failed." });
    expect(response.headers.get("access-control-allow-origin")).toBe("*");
  });
});
