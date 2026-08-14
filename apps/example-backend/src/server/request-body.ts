export const MAX_REQUEST_BODY_BYTES = 64 * 1024;

export class RequestBodyTooLargeError extends Error {
  constructor() {
    super("Request body is too large.");
    this.name = "RequestBodyTooLargeError";
  }
}

export const readLimitedBody = async (
  source: AsyncIterable<Buffer | Uint8Array | string>
): Promise<Buffer> => {
  const chunks: Buffer[] = [];
  let size = 0;

  for await (const chunk of source) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buffer.byteLength;

    if (size > MAX_REQUEST_BODY_BYTES) {
      throw new RequestBodyTooLargeError();
    }

    chunks.push(buffer);
  }

  return Buffer.concat(chunks);
};
