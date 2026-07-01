import { appTrust } from "./config.js";

const trustHeaders = {
  "Cache-Control": "public, max-age=300",
  "Content-Type": "application/json",
};

export const appleAppSiteAssociation = () =>
  Response.json(
    {
      webcredentials: {
        apps: [appTrust.appleAppId],
      },
    },
    {
      headers: trustHeaders,
    }
  );

export const androidAssetLinks = () =>
  Response.json(
    [
      {
        relation: [
          "delegate_permission/common.get_login_creds",
          "delegate_permission/common.handle_all_urls",
        ],
        target: {
          namespace: "android_app",
          package_name: appTrust.androidPackageName,
          sha256_cert_fingerprints: appTrust.androidSha256CertFingerprints,
        },
      },
    ],
    {
      headers: trustHeaders,
    }
  );
