use expo_easy_passkey_core::{
    CeremonyKind as CoreCeremonyKind, PasskeyCoreError, build_client_data_json,
    normalize_base64url, summarize_ceremony, validate_origin, validate_rp_id,
};

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum FfiError {
    #[error("{reason}")]
    Validation { reason: String },
}

impl From<PasskeyCoreError> for FfiError {
    fn from(error: PasskeyCoreError) -> Self {
        Self::Validation {
            reason: error.to_string(),
        }
    }
}

type FfiResult<T> = Result<T, FfiError>;

#[derive(Debug, Clone, Copy, uniffi::Enum)]
pub enum CeremonyKind {
    Create,
    Get,
}

impl From<CeremonyKind> for CoreCeremonyKind {
    fn from(value: CeremonyKind) -> Self {
        match value {
            CeremonyKind::Create => Self::Create,
            CeremonyKind::Get => Self::Get,
        }
    }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct CeremonySummary {
    pub kind: CeremonyKind,
    pub client_data_type: String,
    pub challenge: String,
    pub rp_id: String,
    pub origin: String,
}

#[uniffi::export]
pub fn normalize_challenge(challenge: String) -> FfiResult<String> {
    normalize_base64url(&challenge).map_err(Into::into)
}

#[uniffi::export]
pub fn validate_relying_party_id(rp_id: String) -> FfiResult<String> {
    validate_rp_id(&rp_id).map_err(Into::into)
}

#[uniffi::export]
pub fn validate_ceremony_origin(origin: String) -> FfiResult<String> {
    validate_origin(&origin).map_err(Into::into)
}

#[uniffi::export]
pub fn make_client_data_json(
    kind: CeremonyKind,
    challenge: String,
    origin: String,
    cross_origin: bool,
) -> FfiResult<String> {
    build_client_data_json(kind.into(), &challenge, &origin, cross_origin).map_err(Into::into)
}

#[uniffi::export]
pub fn describe_ceremony(
    kind: CeremonyKind,
    challenge: String,
    rp_id: String,
    origin: String,
) -> FfiResult<CeremonySummary> {
    let summary = summarize_ceremony(kind.into(), &challenge, &rp_id, &origin)?;

    Ok(CeremonySummary {
        kind,
        client_data_type: summary.client_data_type,
        challenge: summary.challenge,
        rp_id: summary.rp_id,
        origin: summary.origin,
    })
}

uniffi::setup_scaffolding!();

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_challenge_through_ffi() {
        assert_eq!(
            normalize_challenge("YWJjZA==".to_owned()).unwrap(),
            "YWJjZA"
        );
    }

    #[test]
    fn validates_relying_party_id_through_ffi() {
        assert_eq!(
            validate_relying_party_id("Example.COM".to_owned()).unwrap(),
            "example.com"
        );
    }

    #[test]
    fn validates_origin_through_ffi() {
        assert_eq!(
            validate_ceremony_origin(" https://example.com ".to_owned()).unwrap(),
            "https://example.com"
        );
    }

    #[test]
    fn builds_client_data_json_through_ffi() {
        let json = make_client_data_json(
            CeremonyKind::Get,
            "YXV0aC1jaGFsbGVuZ2U".to_owned(),
            "https://example.com".to_owned(),
            true,
        )
        .unwrap();

        assert!(json.contains("\"type\":\"webauthn.get\""));
        assert!(json.contains("\"crossOrigin\":true"));
    }

    #[test]
    fn describes_ceremony_through_ffi() {
        let summary = describe_ceremony(
            CeremonyKind::Create,
            "Y2hhbGxlbmdl==".to_owned(),
            "Example.COM".to_owned(),
            " https://example.com ".to_owned(),
        )
        .unwrap();

        assert_eq!(summary.client_data_type, "webauthn.create");
        assert_eq!(summary.challenge, "Y2hhbGxlbmdl");
        assert_eq!(summary.rp_id, "example.com");
        assert_eq!(summary.origin, "https://example.com");
    }

    #[test]
    fn maps_core_errors_to_validation_errors() {
        let error = validate_relying_party_id("https://example.com".to_owned()).unwrap_err();

        assert!(matches!(&error, FfiError::Validation { .. }));
        assert_eq!(error.to_string(), "rpId must be a domain, not a URL");
    }
}
