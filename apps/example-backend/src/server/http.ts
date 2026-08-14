const jsonHeaders = {
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "OPTIONS,POST",
  "Access-Control-Allow-Origin": "*",
  "Content-Type": "application/json",
};

const publicErrorMessages = new Set([
  "Invalid request.",
  "No matching passkey ceremony is pending.",
  "Passkey authentication failed.",
  "Passkey credential was not found.",
  "Passkey registration failed.",
  "Passkey request failed.",
  "Request body is too large.",
  "The passkey ceremony challenge does not match.",
  "The passkey ceremony does not match this request.",
  "The passkey ceremony expired.",
  "The passkey ceremony identifier was not unique.",
]);

export const emptyResponse = (): Response =>
  new Response(null, {
    headers: jsonHeaders,
    status: 204,
  });

export const jsonResponse = (body: unknown, status = 200): Response =>
  Response.json(body, {
    headers: jsonHeaders,
    status,
  });

export const publicErrorMessage = (error: unknown): string => {
  const message = error instanceof Error ? error.message : String(error);
  return publicErrorMessages.has(message) ? message : "Passkey request failed.";
};

export const errorResponse = (error: unknown, status = 400): Response =>
  jsonResponse({ error: publicErrorMessage(error) }, status);
