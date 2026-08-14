// @ts-check

/**
 * @typedef {{
 *   android?: { intentFilters?: unknown[] };
 *   ios?: { associatedDomains?: string[] };
 *   [key: string]: unknown;
 * }} ExpoEasyPasskeyConfig
 *
 * @typedef {{
 *   associatedDomains?: string[];
 *   domains?: string[];
 * }} ExpoEasyPasskeyOptions
 */

const WEBCREDENTIALS_PREFIX = "webcredentials:";

/**
 * @param {string[]} values Values to de-duplicate after removing empty entries.
 * @returns {string[]} Unique non-empty values.
 */
const unique = (values) => [...new Set(values.filter(Boolean))];

/**
 * @param {string} domain Candidate relying-party hostname.
 * @returns {boolean} Whether the value is a hostname without scheme, path, or port.
 */
const isRelyingPartyHostname = (domain) => {
  if (
    domain.length === 0 ||
    domain.includes("://") ||
    domain.includes("/") ||
    domain.includes(":") ||
    domain.includes("@")
  ) {
    return false;
  }

  return domain
    .split(".")
    .every(
      (label) =>
        label.length > 0 &&
        !label.startsWith("-") &&
        !label.endsWith("-") &&
        /^[A-Za-z0-9-]+$/u.test(label)
    );
};

/**
 * @param {string} value Domain or existing webcredentials entry.
 * @returns {string} The original domain or webcredentials entry after validation.
 */
const assertRelyingPartyDomain = (value) => {
  const hostname = value.startsWith(WEBCREDENTIALS_PREFIX)
    ? value.slice(WEBCREDENTIALS_PREFIX.length)
    : value;

  if (!isRelyingPartyHostname(hostname)) {
    throw new Error(
      `Invalid Expo Easy Passkey plugin domain "${value}": Relying Party domains must be hostnames without scheme, path, or port.`
    );
  }

  return value;
};

/**
 * @param {string} domain Domain or existing webcredentials entry.
 * @returns {string} Associated Domains webcredentials entry.
 */
const domainToAssociatedDomain = (domain) =>
  domain.startsWith(WEBCREDENTIALS_PREFIX)
    ? domain
    : `${WEBCREDENTIALS_PREFIX}${domain}`;

/**
 * @param {unknown[]} domains Plugin domain inputs.
 * @returns {string[]} Validated domains after trimming empties.
 */
const normalizePluginDomains = (domains) =>
  domains.flatMap((value) => {
    if (typeof value !== "string") {
      throw new TypeError(
        `Invalid Expo Easy Passkey plugin domain "${String(value)}": Relying Party domains must be hostnames without scheme, path, or port.`
      );
    }

    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return [];
    }

    return [assertRelyingPartyDomain(trimmed)];
  });

/**
 * @param {ExpoEasyPasskeyConfig} config Current Expo config.
 * @param {ExpoEasyPasskeyOptions} options Plugin options.
 * @param {string[]} domains Passkey relying-party domains.
 * @returns {string[]} Merged Associated Domains entries.
 */
const getAssociatedDomains = (config, options, domains) =>
  unique([
    ...(config.ios?.associatedDomains ?? []),
    ...(options.associatedDomains ?? []),
    ...domains.map(domainToAssociatedDomain),
  ]);

/**
 * @param {ExpoEasyPasskeyConfig} config Expo config to mutate.
 * @param {string[]} associatedDomains Associated Domains entries to apply.
 */
const applyAssociatedDomains = (config, associatedDomains) => {
  if (associatedDomains.length > 0) {
    config.ios = {
      ...config.ios,
      associatedDomains,
    };
  }
};

/**
 * @param {ExpoEasyPasskeyConfig} config Expo config passed by config plugins.
 * @param {ExpoEasyPasskeyOptions} [options] Expo Easy Passkey plugin options.
 * @returns {ExpoEasyPasskeyConfig} Updated Expo config.
 */
export default function withExpoEasyPasskey(config, options = {}) {
  const domains = normalizePluginDomains(options.domains ?? []);

  applyAssociatedDomains(
    config,
    getAssociatedDomains(config, options, domains)
  );

  return config;
}
