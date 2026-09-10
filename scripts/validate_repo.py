#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

JSON_GLOBS = (
    "workflows/*.json",
    "samples/*.json",
    "PROJECT_MANIFEST.json",
)

SECRET_PATTERNS = {
    "OpenAI-style API key": re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"),
    "PEM private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
}

TEXT_SUFFIXES = {".md", ".json", ".ps1", ".cmd", ".html", ".py", ".yml", ".yaml", ".env", ".example"}


def validate_json() -> list[str]:
    errors: list[str] = []
    seen: set[Path] = set()
    for pattern in JSON_GLOBS:
        paths = [ROOT / pattern] if "*" not in pattern else list(ROOT.glob(pattern))
        for path in paths:
            if not path.exists() or path in seen:
                continue
            seen.add(path)
            try:
                json.loads(path.read_text(encoding="utf-8"))
            except Exception as exc:
                errors.append(f"Invalid JSON: {path.relative_to(ROOT)}: {exc}")
    return errors


def scan_secrets() -> list[str]:
    errors: list[str] = []
    skip_parts = {".git", "__pycache__"}
    for path in ROOT.rglob("*"):
        if not path.is_file() or any(part in skip_parts for part in path.parts):
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name not in {".env.example", ".gitignore"}:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for label, pattern in SECRET_PATTERNS.items():
            if pattern.search(text):
                errors.append(f"Potential secret ({label}) in {path.relative_to(ROOT)}")
    return errors


def validate_manifest() -> list[str]:
    errors: list[str] = []
    manifest_path = ROOT / "PROJECT_MANIFEST.json"
    if not manifest_path.exists():
        return ["PROJECT_MANIFEST.json is missing"]
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for workflow in manifest.get("workflows", []):
        path = ROOT / "workflows" / workflow
        if not path.exists():
            errors.append(f"Manifest references missing workflow: workflows/{workflow}")
    regression = manifest.get("regression", {})
    if regression.get("pass") != 11 or regression.get("fail") != 0:
        errors.append("Manifest regression summary is expected to remain 11 pass / 0 fail")
    if manifest.get("sanitized") is not True:
        errors.append("Manifest must explicitly mark public exports as sanitized")
    return errors


def main() -> int:
    errors = validate_json() + validate_manifest() + scan_secrets()
    if errors:
        print("Repository validation FAILED")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Repository validation PASSED")
    print("- JSON files parse successfully")
    print("- Manifest references existing workflow exports")
    print("- Regression manifest remains 11/11")
    print("- No obvious committed secrets detected")
    return 0


if __name__ == "__main__":
    sys.exit(main())
