import app from "../src/index.js";

const API_PATH_PREFIX = "/api";

const normalizeRequest = (request: Request): Request => {
  const { headers } = request;
  const host =
    headers.get("x-forwarded-host") ?? headers.get("host") ?? "localhost";
  const proto = headers.get("x-forwarded-proto") ?? "https";
  const url = new URL(request.url, `${proto}://${host}`);
  const rewrittenPath = url.searchParams.get("path");

  if (rewrittenPath) {
    url.pathname = `/${rewrittenPath}`;
    url.searchParams.delete("path");
  } else if (url.pathname === API_PATH_PREFIX) {
    url.pathname = "/";
  } else if (url.pathname.startsWith(`${API_PATH_PREFIX}/`)) {
    url.pathname = url.pathname.slice(API_PATH_PREFIX.length);
  }

  return new Request(url, request);
};

const handler = (request: Request): Response | Promise<Response> =>
  app.handle(normalizeRequest(request));

export default handler;
