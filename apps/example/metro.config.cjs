const path = require("node:path");
const { getDefaultConfig } = require("expo/metro-config");

const config = getDefaultConfig(__dirname);
const moduleSourceRoot = path.resolve(__dirname, "../../packages/module/src");

const isModuleSourceFile = (filePath) =>
  filePath === moduleSourceRoot ||
  filePath.startsWith(`${moduleSourceRoot}${path.sep}`);

config.resolver.resolveRequest = (context, moduleName, platform) => {
  try {
    return context.resolveRequest(context, moduleName, platform);
  } catch (error) {
    if (
      isModuleSourceFile(context.originModulePath) &&
      /^\.\.?\/.*\.js$/u.test(moduleName)
    ) {
      return context.resolveRequest(
        context,
        moduleName.replace(/\.js$/u, ""),
        platform
      );
    }

    throw error;
  }
};

module.exports = config;
