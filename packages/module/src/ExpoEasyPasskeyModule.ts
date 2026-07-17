import { Platform, requireOptionalNativeModule } from "expo-modules-core";

import type { ExpoEasyPasskeyNativeModule, PasskeyPlatform } from "./types.js";
import {
  MISSING_NATIVE_MODULE_MESSAGE,
  WEB_UNSUPPORTED_MESSAGE,
  createUnsupportedPasskeyModule,
} from "./unsupportedPasskeyModule.js";

const resolvePlatform = (): PasskeyPlatform => {
  if (
    Platform.OS === "ios" ||
    Platform.OS === "android" ||
    Platform.OS === "web"
  ) {
    return Platform.OS;
  }

  return "unknown";
};

const unsupportedMessageFor = (platform: PasskeyPlatform): string =>
  platform === "web" ? WEB_UNSUPPORTED_MESSAGE : MISSING_NATIVE_MODULE_MESSAGE;

const nativeModule =
  requireOptionalNativeModule<ExpoEasyPasskeyNativeModule>("ExpoEasyPasskey");

const platform = resolvePlatform();

export default nativeModule ??
  createUnsupportedPasskeyModule(platform, unsupportedMessageFor(platform));
