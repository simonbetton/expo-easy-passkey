import type {
  IncomingHttpHeaders,
  IncomingMessage,
  ServerResponse,
} from "node:http";

import app from "../src/index.js";

const API_PATH_PREFIX = "/api";
const BODYLESS_METHODS = new Set(["GET", "HEAD"]);

const getHeader = (
  headers: IncomingHttpHeaders,
  name: string
): string | undefined => {
  const value = headers[name.toLowerCase()];

  return Array.isArray(value) ? value[0] : value;
};

const toWebHeaders = (nodeHeaders: IncomingHttpHeaders): Headers => {
  const headers = new Headers();

  for (const [name, value] of Object.entries(nodeHeaders)) {
    if (typeof value === "string") {
      headers.set(name, value);
    } else if (Array.isArray(value)) {
      for (const item of value) {
        headers.append(name, item);
      }
    }
  }

  return headers;
};

const readBody = async (
  request: IncomingMessage
): Promise<Blob | undefined> => {
  if (BODYLESS_METHODS.has(request.method?.toUpperCase() ?? "GET")) {
    return;
  }

  const chunks: Buffer[] = [];

  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }

  const body = Buffer.concat(chunks);

  return body.byteLength > 0 ? new Blob([new Uint8Array(body)]) : undefined;
};

const normalizeUrl = (url: URL): URL => {
  const rewrittenPath = url.searchParams.get("path");

  if (rewrittenPath) {
    url.pathname = `/${rewrittenPath}`;
    url.searchParams.delete("path");
  } else if (url.pathname === API_PATH_PREFIX) {
    url.pathname = "/";
  } else if (url.pathname.startsWith(`${API_PATH_PREFIX}/`)) {
    url.pathname = url.pathname.slice(API_PATH_PREFIX.length);
  }

  return url;
};

const toWebRequest = async (request: IncomingMessage): Promise<Request> => {
  const { headers } = request;
  const host =
    getHeader(headers, "x-forwarded-host") ??
    getHeader(headers, "host") ??
    "localhost";
  const proto = getHeader(headers, "x-forwarded-proto") ?? "https";
  const url = normalizeUrl(new URL(request.url ?? "/", `${proto}://${host}`));

  return new Request(url, {
    body: await readBody(request),
    headers: toWebHeaders(headers),
    method: request.method ?? "GET",
  });
};

const sendWebResponse = async (
  response: Response,
  reply: ServerResponse
): Promise<void> => {
  reply.statusCode = response.status;

  const responseHeaders = response.headers as unknown as Iterable<
    [string, string]
  >;

  for (const [name, value] of responseHeaders) {
    reply.setHeader(name, value);
  }

  if (!response.body) {
    reply.end();
    return;
  }

  reply.end(Buffer.from(await response.arrayBuffer()));
};

const handler = async (
  request: IncomingMessage,
  response: ServerResponse
): Promise<void> => {
  await sendWebResponse(
    await app.handle(await toWebRequest(request)),
    response
  );
};

export default handler;
