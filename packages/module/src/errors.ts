import type { PasskeyErrorCode } from "./types.js";

const passkeyErrorCodes = new Set<string>([
  "ERR_PASSKEY_ACTIVITY",
  "ERR_PASSKEY_CANCELED",
  "ERR_PASSKEY_CREATE",
  "ERR_PASSKEY_GET",
  "ERR_PASSKEY_INVALID_CREDENTIAL",
  "ERR_PASSKEY_INVALID_RESPONSE",
  "ERR_PASSKEY_NATIVE",
  "ERR_PASSKEY_NO_CREDENTIAL",
  "ERR_PASSKEY_PRESENTATION_CONTEXT",
  "ERR_PASSKEY_UNSUPPORTED",
  "ERR_PASSKEY_VALIDATION",
]);

const isPasskeyErrorCode = (code: unknown): code is PasskeyErrorCode =>
  typeof code === "string" && passkeyErrorCodes.has(code);

export class PasskeyError extends Error {
  public readonly code: PasskeyErrorCode;

  public override readonly cause?: unknown;

  constructor(message: string, code: PasskeyErrorCode, cause?: unknown) {
    super(message);
    this.code = code;
    this.cause = cause;
    this.name = "PasskeyError";
  }
}

export const toPasskeyError = (
  cause: unknown,
  fallbackCode: PasskeyErrorCode
): PasskeyError => {
  if (cause instanceof PasskeyError) {
    return cause;
  }

  if (cause instanceof Error) {
    const nativeCode = (cause as Error & { code?: unknown }).code;
    const code = isPasskeyErrorCode(nativeCode) ? nativeCode : fallbackCode;

    return new PasskeyError(cause.message, code, cause);
  }

  return new PasskeyError("Unknown passkey error", fallbackCode, cause);
};
