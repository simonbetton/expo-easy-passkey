const jsonHeaders = {
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "OPTIONS,POST",
  "Access-Control-Allow-Origin": "*",
  "Content-Type": "application/json",
};

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

export const errorResponse = (error: unknown, status = 400): Response => {
  const message = error instanceof Error ? error.message : String(error);

  return jsonResponse({ error: message }, status);
};
