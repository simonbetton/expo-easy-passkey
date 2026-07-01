import type {
  AuthenticationResponseJSON,
  PublicKeyCredentialCreationOptionsJSON,
  PublicKeyCredentialRequestOptionsJSON,
  RegistrationResponseJSON,
} from "expo-easy-passkey";
import { fetch } from "expo/fetch";

export interface RegistrationVerification {
  credentialId: string;
  verified: true;
}

export interface AuthenticationVerification {
  session: {
    credentialId: string;
    expiresInSeconds: number;
    token: string;
  };
  verified: true;
}

export const apiBaseUrl =
  process.env.EXPO_PUBLIC_PASSKEY_API_BASE_URL ??
  "https://expo-easy-passkey-example-backend.vercel.app";

const postJson = async <ResponseBody>(
  path: string,
  body?: unknown
): Promise<ResponseBody> => {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    body: body === undefined ? undefined : JSON.stringify(body),
    headers: { "content-type": "application/json" },
    method: "POST",
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message);
  }

  return response.json() as Promise<ResponseBody>;
};

export const fetchRegistrationOptions = () =>
  postJson<PublicKeyCredentialCreationOptionsJSON>(
    "/passkeys/register/options"
  );

export const verifyRegistration = (credential: RegistrationResponseJSON) =>
  postJson<RegistrationVerification>("/passkeys/register/verify", credential);

export const fetchAuthenticationOptions = () =>
  postJson<PublicKeyCredentialRequestOptionsJSON>(
    "/passkeys/authenticate/options"
  );

export const verifyAuthentication = (assertion: AuthenticationResponseJSON) =>
  postJson<AuthenticationVerification>(
    "/passkeys/authenticate/verify",
    assertion
  );
