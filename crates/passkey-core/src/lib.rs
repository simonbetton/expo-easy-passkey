use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum PasskeyCoreError {
    #[error("base64url value is empty")]
    EmptyBase64Url,
    #[error("base64url value is invalid")]
    InvalidBase64Url,
    #[error("rpId is empty")]
    EmptyRpId,
    #[error("rpId must be a domain, not a URL")]
    RpIdLooksLikeUrl,
    #[error("rpId contains an invalid domain label")]
    InvalidRpIdLabel,
    #[error("origin is empty")]
    EmptyOrigin,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum CeremonyKind {
    Create,
    Get,
}

impl CeremonyKind {
    pub fn client_data_type(self) -> &'static str {
        match self {
            Self::Create => "webauthn.create",
            Self::Get => "webauthn.get",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClientDataJson {
    #[serde(rename = "type")]
    pub ceremony_type: String,
    pub challenge: String,
    pub origin: String,
    pub cross_origin: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CeremonySummary {
    pub kind: CeremonyKind,
    pub client_data_type: String,
    pub challenge: String,
    pub rp_id: String,
    pub origin: String,
}

pub fn normalize_base64url(input: &str) -> Result<String, PasskeyCoreError> {
    let trimmed = input.trim();

    if trimmed.is_empty() {
        return Err(PasskeyCoreError::EmptyBase64Url);
    }

    let normalized = trimmed
        .trim_end_matches('=')
        .replace('+', "-")
        .replace('/', "_");

    URL_SAFE_NO_PAD
        .decode(normalized.as_bytes())
        .map_err(|_| PasskeyCoreError::InvalidBase64Url)?;

    Ok(normalized)
}

pub fn validate_rp_id(rp_id: &str) -> Result<String, PasskeyCoreError> {
    let normalized = rp_id.trim().to_ascii_lowercase();

    if normalized.is_empty() {
        return Err(PasskeyCoreError::EmptyRpId);
    }

    if normalized.contains("://")
        || normalized.contains('/')
        || normalized.contains(':')
        || normalized.contains('@')
    {
        return Err(PasskeyCoreError::RpIdLooksLikeUrl);
    }

    for label in normalized.split('.') {
        let valid_label = !label.is_empty()
            && !label.starts_with('-')
            && !label.ends_with('-')
            && label
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-');

        if !valid_label {
            return Err(PasskeyCoreError::InvalidRpIdLabel);
        }
    }

    Ok(normalized)
}

pub fn validate_origin(origin: &str) -> Result<String, PasskeyCoreError> {
    let normalized = origin.trim();

    if normalized.is_empty() {
        return Err(PasskeyCoreError::EmptyOrigin);
    }

    Ok(normalized.to_owned())
}

pub fn build_client_data_json(
    kind: CeremonyKind,
    challenge: &str,
    origin: &str,
    cross_origin: bool,
) -> Result<String, PasskeyCoreError> {
    let origin = validate_origin(origin)?;

    let client_data = ClientDataJson {
        ceremony_type: kind.client_data_type().to_owned(),
        challenge: normalize_base64url(challenge)?,
        origin,
        cross_origin,
    };

    serde_json::to_string(&client_data).map_err(|_| PasskeyCoreError::InvalidBase64Url)
}

pub fn summarize_ceremony(
    kind: CeremonyKind,
    challenge: &str,
    rp_id: &str,
    origin: &str,
) -> Result<CeremonySummary, PasskeyCoreError> {
    Ok(CeremonySummary {
        kind,
        client_data_type: kind.client_data_type().to_owned(),
        challenge: normalize_base64url(challenge)?,
        rp_id: validate_rp_id(rp_id)?,
        origin: validate_origin(origin)?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde::Deserialize;

    #[derive(Debug, Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct CeremonyVectorFile {
        valid: Vec<ValidCeremonyVector>,
        invalid: Vec<InvalidCeremonyVector>,
    }

    #[derive(Debug, Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct ValidCeremonyVector {
        kind: String,
        rp_id: String,
        origin: String,
        challenge: String,
        normalized_challenge: String,
        client_data_type: String,
        cross_origin: bool,
    }

    #[derive(Debug, Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct InvalidCeremonyVector {
        name: String,
        kind: String,
        rp_id: String,
        origin: String,
        challenge: String,
        expected_error: String,
    }

    fn kind_from_vector(kind: &str) -> CeremonyKind {
        match kind {
            "create" => CeremonyKind::Create,
            "get" => CeremonyKind::Get,
            _ => panic!("unsupported ceremony kind in fixture: {kind}"),
        }
    }

    fn vectors() -> CeremonyVectorFile {
        serde_json::from_str(include_str!("../test-vectors/ceremonies.json"))
            .expect("ceremony vectors should parse")
    }

    #[test]
    fn normalizes_base64url_padding() {
        assert_eq!(normalize_base64url("YWJjZA==").unwrap(), "YWJjZA");
    }

    #[test]
    fn normalizes_standard_base64_characters() {
        assert_eq!(normalize_base64url("+/8=").unwrap(), "-_8");
    }

    #[test]
    fn rejects_invalid_base64url() {
        assert_eq!(
            normalize_base64url("not valid base64!").unwrap_err(),
            PasskeyCoreError::InvalidBase64Url
        );
    }

    #[test]
    fn rejects_empty_base64url() {
        assert_eq!(
            normalize_base64url("   ").unwrap_err(),
            PasskeyCoreError::EmptyBase64Url
        );
    }

    #[test]
    fn rejects_url_as_rp_id() {
        assert_eq!(
            validate_rp_id("https://example.com").unwrap_err(),
            PasskeyCoreError::RpIdLooksLikeUrl
        );
    }

    #[test]
    fn validates_rp_id_label_rules() {
        assert_eq!(validate_rp_id("Example.COM").unwrap(), "example.com");

        for rp_id in [
            "-example.com",
            "example-.com",
            "example..com",
            "exa_mple.com",
        ] {
            assert_eq!(
                validate_rp_id(rp_id).unwrap_err(),
                PasskeyCoreError::InvalidRpIdLabel
            );
        }
    }

    #[test]
    fn rejects_empty_origin() {
        assert_eq!(
            validate_origin("   ").unwrap_err(),
            PasskeyCoreError::EmptyOrigin
        );
    }

    #[test]
    fn builds_registration_client_data_json() {
        let json = build_client_data_json(
            CeremonyKind::Create,
            "Y2hhbGxlbmdl",
            "https://example.com",
            false,
        )
        .unwrap();

        assert!(json.contains("\"type\":\"webauthn.create\""));
        assert!(json.contains("\"challenge\":\"Y2hhbGxlbmdl\""));
    }

    #[test]
    fn builds_authentication_client_data_json_with_cross_origin() {
        let json = build_client_data_json(
            CeremonyKind::Get,
            "YXV0aC1jaGFsbGVuZ2U",
            "https://example.com",
            true,
        )
        .unwrap();
        let client_data: ClientDataJson = serde_json::from_str(&json).unwrap();

        assert_eq!(client_data.ceremony_type, "webauthn.get");
        assert_eq!(client_data.challenge, "YXV0aC1jaGFsbGVuZ2U");
        assert!(client_data.cross_origin);
    }

    #[test]
    fn summarizes_ceremony_inputs() {
        let summary = summarize_ceremony(
            CeremonyKind::Create,
            "Y2hhbGxlbmdl==",
            "Example.COM",
            " https://example.com ",
        )
        .unwrap();

        assert_eq!(summary.kind, CeremonyKind::Create);
        assert_eq!(summary.client_data_type, "webauthn.create");
        assert_eq!(summary.challenge, "Y2hhbGxlbmdl");
        assert_eq!(summary.rp_id, "example.com");
        assert_eq!(summary.origin, "https://example.com");
    }

    #[test]
    fn valid_vectors_round_trip() {
        for vector in vectors().valid {
            let kind = kind_from_vector(&vector.kind);
            let summary =
                summarize_ceremony(kind, &vector.challenge, &vector.rp_id, &vector.origin).unwrap();
            let client_data_json = build_client_data_json(
                kind,
                &vector.challenge,
                &vector.origin,
                vector.cross_origin,
            )
            .unwrap();
            let client_data: ClientDataJson = serde_json::from_str(&client_data_json).unwrap();

            assert_eq!(summary.client_data_type, vector.client_data_type);
            assert_eq!(summary.challenge, vector.normalized_challenge);
            assert_eq!(summary.rp_id, vector.rp_id.trim().to_ascii_lowercase());
            assert_eq!(client_data.ceremony_type, vector.client_data_type);
            assert_eq!(client_data.challenge, vector.normalized_challenge);
            assert_eq!(client_data.origin, vector.origin.trim());
            assert_eq!(client_data.cross_origin, vector.cross_origin);
        }
    }

    #[test]
    fn invalid_vectors_fail_with_expected_errors() {
        for vector in vectors().invalid {
            let kind = kind_from_vector(&vector.kind);
            let error = summarize_ceremony(kind, &vector.challenge, &vector.rp_id, &vector.origin)
                .unwrap_err();

            assert_eq!(error.to_string(), vector.expected_error, "{}", vector.name);
        }
    }
}
