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

import {
  apiBaseUrl,
  fetchAuthenticationOptions,
  fetchRegistrationOptions,
  verifyAuthentication,
  verifyRegistration,
} from "./src/passkey-api";

const styles = StyleSheet.create({
  actions: {
    gap: 12,
    marginVertical: 24,
  },
  banner: {
    backgroundColor: "#fef3c7",
    borderColor: "#f59e0b",
    borderRadius: 12,
    borderWidth: 1,
    marginTop: 16,
    padding: 16,
  },
  bannerText: {
    color: "#78350f",
    fontSize: 15,
    fontWeight: "600",
    lineHeight: 22,
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

const runRegistration = async () => {
  const { ceremonyId, options } = await fetchRegistrationOptions();
  const credential = await createPasskey(options);
  const verification = await verifyRegistration(ceremonyId, credential);

  return {
    ceremony: "registration",
    verification,
  };
};

const runAuthentication = async () => {
  const { ceremonyId, options } = await fetchAuthenticationOptions();
  const assertion = await authenticateWithPasskey(options);
  const verification = await verifyAuthentication(ceremonyId, assertion);

  return {
    ceremony: "authentication",
    verification,
  };
};

const formatCeremonyError = (error: unknown) => {
  if (error instanceof PasskeyError) {
    return `${error.code}: ${error.message}`;
  }

  return error instanceof Error ? error.message : String(error);
};

export default function App() {
  const availability = useMemo(() => getPasskeyAvailability(), []);
  const [output, setOutput] = useState(
    "Register a passkey, then authenticate with it."
  );

  const run = async (kind: "create" | "get") => {
    try {
      const result =
        kind === "create" ? await runRegistration() : await runAuthentication();
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
        <Text style={styles.body}>Backend: {apiBaseUrl}</Text>
        <View style={styles.banner}>
          <Text style={styles.bannerText}>
            Demo backend storage is in memory. Registered passkeys and pending
            challenges can be lost at any time.
          </Text>
        </View>
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
