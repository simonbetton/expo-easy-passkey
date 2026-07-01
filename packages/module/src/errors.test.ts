import { PasskeyError, toPasskeyError } from "./errors.js";

describe("toPasskeyError", () => {
  it("returns existing PasskeyError values unchanged", () => {
    const error = new PasskeyError("Invalid", "ERR_PASSKEY_VALIDATION");

    expect(toPasskeyError(error, "ERR_PASSKEY_NATIVE")).toBe(error);
  });

  it("preserves native coded exception codes", () => {
    const nativeError = Object.assign(new Error("Canceled"), {
      code: "ERR_PASSKEY_CANCELED",
    });

    expect(toPasskeyError(nativeError, "ERR_PASSKEY_NATIVE")).toMatchObject({
      code: "ERR_PASSKEY_CANCELED",
      message: "Canceled",
    });
  });

  it("uses the fallback code for uncoded errors", () => {
    expect(
      toPasskeyError(new Error("Failed"), "ERR_PASSKEY_GET")
    ).toMatchObject({
      code: "ERR_PASSKEY_GET",
      message: "Failed",
    });
  });

  it("uses the fallback code for undocumented native codes", () => {
    const nativeError = Object.assign(new Error("Failed"), {
      code: "ERR_VENDOR_SPECIFIC",
    });

    expect(toPasskeyError(nativeError, "ERR_PASSKEY_NATIVE")).toMatchObject({
      code: "ERR_PASSKEY_NATIVE",
      message: "Failed",
    });
  });

  it("wraps non-error causes with the fallback code", () => {
    expect(toPasskeyError("failed", "ERR_PASSKEY_GET")).toMatchObject({
      cause: "failed",
      code: "ERR_PASSKEY_GET",
      message: "Unknown passkey error",
    });
  });
});
