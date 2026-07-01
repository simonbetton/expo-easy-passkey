import { requireNativeModule } from "expo-modules-core";

import type { ExpoEasyPasskeyNativeModule } from "./types.js";

export default requireNativeModule<ExpoEasyPasskeyNativeModule>(
  "ExpoEasyPasskey"
);
