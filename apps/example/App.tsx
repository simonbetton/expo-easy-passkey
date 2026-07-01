import {
  authenticateWithPasskey,
  createPasskey,
  getPasskeyAvailability,
  PasskeyError,
} from "expo-easy-passkey";
import { useMemo, useState } from "react";
import {
  Button,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";

// Demo-only challenge values. They are base64url-encoded strings:
// "registration-challenge" and "authentication-challenge".
// Production apps should request fresh, random challenges from the backend
// for every registration or authentication ceremony, then verify them server-side.
const registrationOptions = {
  attestation: "none" as const,
  authenticatorSelection: {
    authenticatorAttachment: "platform" as const,
    residentKey: "preferred" as const,
    userVerification: "preferred" as const,
  },
  challenge: "cmVnaXN0cmF0aW9uLWNoYWxsZW5nZQ",
  origin: "https://expo-easy-passkey.vercel.app",
  pubKeyCredParams: [{ alg: -7, type: "public-key" as const }],
  rp: {
    id: "expo-easy-passkey.vercel.app",
    name: "Expo Easy Passkey",
  },
  user: {
    displayName: "Demo User",
    id: "ZXhhbXBsZS11c2Vy",
    name: "demo@expo-easy-passkey.vercel.app",
  },
};

const authenticationOptions = {
  challenge: "YXV0aGVudGljYXRpb24tY2hhbGxlbmdl",
  origin: "https://expo-easy-passkey.vercel.app",
  rpId: "expo-easy-passkey.vercel.app",
  userVerification: "preferred" as const,
};

const styles = StyleSheet.create({
  actions: {
    gap: 12,
    marginVertical: 24,
  },
  body: {
    fontSize: 16,
    lineHeight: 24,
  },
  content: {
    padding: 24,
  },
  output: {
    backgroundColor: "#111827",
    borderRadius: 12,
    color: "#f9fafb",
    fontFamily: "Menlo",
    fontSize: 13,
    lineHeight: 20,
    padding: 16,
  },
  screen: {
    backgroundColor: "#ffffff",
    flex: 1,
  },
  title: {
    fontSize: 28,
    fontWeight: "700",
    marginBottom: 12,
  },
});

const runCeremony = (kind: "create" | "get") =>
  kind === "create"
    ? createPasskey(registrationOptions)
    : authenticateWithPasskey(authenticationOptions);

const formatCeremonyError = (error: unknown) => {
  if (error instanceof PasskeyError) {
    return `${error.code}: ${error.message}`;
  }

  return error instanceof Error ? error.message : String(error);
};

export default function App() {
  const availability = useMemo(() => getPasskeyAvailability(), []);
  const [output, setOutput] = useState(
    "Run a ceremony to see the bridge response."
  );

  const run = async (kind: "create" | "get") => {
    try {
      const result = await runCeremony(kind);
      setOutput(JSON.stringify(result, null, 2));
    } catch (error) {
      setOutput(formatCeremonyError(error));
    }
  };

  return (
    <SafeAreaView style={styles.screen}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>Expo Easy Passkey</Text>
        <Text style={styles.body}>
          Native support reported: {availability.supported ? "yes" : "no"} on{" "}
          {availability.platform}
        </Text>
        <View style={styles.actions}>
          <Button
            disabled={!availability.supported}
            title="Register passkey"
            onPress={() => void run("create")}
          />
          <Button
            disabled={!availability.supported}
            title="Authenticate"
            onPress={() => void run("get")}
          />
        </View>
        <Text style={styles.output}>{output}</Text>
      </ScrollView>
    </SafeAreaView>
  );
}
