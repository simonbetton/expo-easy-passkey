import { Readable } from "node:stream";

import { describe, expect, it } from "@jest/globals";

import {
  MAX_REQUEST_BODY_BYTES,
  RequestBodyTooLargeError,
  readLimitedBody,
} from "./request-body.js";

describe("limited request body reader", () => {
  it("concatenates chunks under the size ceiling", async () => {
    const body = await readLimitedBody(
      Readable.from([Buffer.from("hel"), Buffer.from("lo")])
    );

    expect(body.toString("utf-8")).toBe("hello");
  });

  it("rejects oversized bodies before concatenating the remainder", async () => {
    const oversized = Buffer.alloc(MAX_REQUEST_BODY_BYTES + 1, 97);

    await expect(readLimitedBody(Readable.from([oversized]))).rejects.toThrow(
      RequestBodyTooLargeError
    );
    await expect(readLimitedBody(Readable.from([oversized]))).rejects.toThrow(
      "Request body is too large."
    );
  });
});
