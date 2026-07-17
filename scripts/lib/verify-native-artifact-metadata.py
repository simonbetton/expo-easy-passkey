#!/usr/bin/env python3
"""Verify native artifact metadata inventories and checksums.

Usage:
  verify-native-artifact-metadata.py <root> <metadata.json> <android|apple> [expected-source-commit]

When expected-source-commit is provided, metadata sourceCommit must match.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

EXPECTED_TARGETS = {
    "android": {
        "android-arm64-v8a",
        "android-armeabi-v7a",
        "android-x86",
        "android-x86_64",
    },
    "apple": {
        "apple-ios-arm64",
        "apple-ios-arm64_x86_64-simulator",
    },
}


def main() -> None:
    if len(sys.argv) not in {4, 5}:
        raise SystemExit(
            "Usage: verify-native-artifact-metadata.py "
            "<root> <metadata.json> <android|apple> [expected-source-commit]"
        )

    root = Path(sys.argv[1])
    meta_path = Path(sys.argv[2])
    platform = sys.argv[3]
    expected_commit = sys.argv[4] if len(sys.argv) == 5 else None

    if platform not in EXPECTED_TARGETS:
        raise SystemExit(f"Unsupported platform: {platform!r}")

    meta = json.loads(meta_path.read_text(encoding="utf-8"))

    if meta.get("platform") not in {platform, "all"}:
        raise SystemExit(
            f"{platform} metadata platform is {meta.get('platform')!r}"
        )

    if expected_commit is not None and meta.get("sourceCommit") != expected_commit:
        raise SystemExit(
            f"{platform} metadata sourceCommit {meta.get('sourceCommit')!r} "
            f"does not match expected {expected_commit!r}"
        )

    expected = EXPECTED_TARGETS[platform]
    targets = meta.get("targets") or []
    ids = {target["id"] for target in targets}
    missing = expected - ids
    if missing:
        raise SystemExit(f"{platform} metadata missing targets: {sorted(missing)}")

    for target in targets:
        if target["id"] not in expected:
            continue
        path = root / target["path"]
        if not path.is_file():
            raise SystemExit(f"Missing required {platform} artifact: {path}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != target["sha256"]:
            raise SystemExit(
                f"Stale or mismatched {platform} artifact for {target['id']}: "
                f"expected sha256 {target['sha256']}, got {digest}"
            )

    label = "trusted " if expected_commit is not None else ""
    print(
        f"Verified {label}{len(expected)} {platform} artifact checksums "
        f"against immutable metadata"
    )


if __name__ == "__main__":
    main()
