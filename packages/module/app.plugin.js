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

/**
 * @param {string[]} values Values to de-duplicate after removing empty entries.
 * @returns {string[]} Unique non-empty values.
 */
const unique = (values) => [...new Set(values.filter(Boolean))];

/**
 * @param {string} domain Domain or existing webcredentials entry.
 * @returns {string} Associated Domains webcredentials entry.
 */
const domainToAssociatedDomain = (domain) =>
  domain.startsWith("webcredentials:") ? domain : `webcredentials:${domain}`;

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
  const domains = options.domains ?? [];

  applyAssociatedDomains(
    config,
    getAssociatedDomains(config, options, domains)
  );

  return config;
}
