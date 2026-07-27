#!/usr/bin/env python3
"""Convert normalized DevSecOps findings into AWS Security Hub ASFF.

FIXED VERSION: Outputs direct array of ASFF findings for BatchImportFindings API.
AWS Security Hub expects: [{ SchemaVersion, Id, ProductArn, ... }, ...]
NOT: { schemaVersion, findings: [...] }
"""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ASFF_SEVERITIES = {"CRITICAL", "HIGH", "MEDIUM", "LOW", "INFORMATIONAL"}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, sort_keys=False)
        handle.write("\n")


def clean_account_id(account_id: str) -> str:
    cleaned = re.sub(r"\D", "", account_id)
    if len(cleaned) != 12:
        raise ValueError("AWS account id must contain 12 digits")
    return cleaned


def limit_text(value: Any, max_len: int) -> str:
    text = "" if value is None else str(value)
    if len(text) <= max_len:
        return text
    return text[: max_len - 3] + "..."


def severity_label(value: Any) -> str:
    label = str(value or "INFORMATIONAL").upper()
    return label if label in ASFF_SEVERITIES else "INFORMATIONAL"


def finding_type(category: str) -> str:
    return {
        "secrets": "Software and Configuration Checks/Industry and Regulatory Standards",
        "sca": "Software and Configuration Checks/Vulnerabilities",
        "container": "Software and Configuration Checks/Vulnerabilities",
        "sast": "Software and Configuration Checks/Vulnerabilities",
        "dast": "Software and Configuration Checks/Vulnerabilities",
        "iac": "Software and Configuration Checks/AWS Security Best Practices",
    }.get(category, "Software and Configuration Checks")


def str_map(data: dict[str, Any]) -> dict[str, str]:
    return {key: limit_text(value, 1024) for key, value in data.items() if value is not None}


def build_asff_finding(
    finding: dict[str, Any],
    metadata: dict[str, Any],
    *,
    account_id: str,
    region: str,
    product_arn: str,
    product_name: str,
    company_name: str,
    timestamp: str,
) -> dict[str, Any]:
    tool = finding.get("tool", "unknown")
    category = finding.get("category", "unknown")
    resource_id = finding.get("resource") or finding.get("file") or metadata.get("app") or "unknown"
    extra = finding.get("extra") or {}

    product_fields = {
        "App": metadata.get("app"),
        "Environment": metadata.get("environment"),
        "Commit": metadata.get("commit"),
        "BuildNumber": metadata.get("buildNumber"),
        "Tool": tool,
        "Category": category,
        "ResourceType": finding.get("resourceType"),
        "File": finding.get("file"),
        "Line": finding.get("line"),
        "CVE": finding.get("cve"),
        "CWE": finding.get("cwe"),
        "RawReport": finding.get("rawReport"),
    }
    for key, value in extra.items():
        product_fields[f"Extra/{key}"] = value

    asff_id = f"devsecops/{category}/{tool}/{finding.get('id')}"
    recommendation = finding.get("remediation") or "Review the original scanner report and remediate the finding."

    return {
        "SchemaVersion": "2018-10-08",
        "Id": asff_id,
        "ProductArn": product_arn,
        "ProductName": product_name,
        "CompanyName": company_name,
        "GeneratorId": f"{tool}/{category}",
        "AwsAccountId": account_id,
        "Types": [finding_type(category)],
        "CreatedAt": timestamp,
        "UpdatedAt": timestamp,
        "FirstObservedAt": timestamp,
        "LastObservedAt": timestamp,
        "Severity": {"Label": severity_label(finding.get("severity"))},
        "Title": limit_text(finding.get("title"), 256),
        "Description": limit_text(finding.get("description"), 1024),
        "Resources": [
            {
                "Type": "Other",
                "Id": limit_text(resource_id, 512),
                "Partition": "aws",
                "Region": region,
                "Details": {
                    "Other": str_map(
                        {
                            "ResourceType": finding.get("resourceType"),
                            "Resource": resource_id,
                            "File": finding.get("file"),
                            "Line": finding.get("line"),
                            "RawReport": finding.get("rawReport"),
                        }
                    )
                },
            }
        ],
        "Remediation": {
            "Recommendation": {
                "Text": limit_text(recommendation, 512),
            }
        },
        "ProductFields": str_map(product_fields),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Security Hub ASFF findings.")
    parser.add_argument("--input", required=True, help="Normalized findings JSON path.")
    parser.add_argument("--out", required=True, help="Output ASFF JSON path.")
    parser.add_argument("--region", required=True)
    parser.add_argument("--account-id", required=True)
    parser.add_argument("--product-name", default="DevSecOps Software Factory")
    parser.add_argument("--company-name", default="Student DevSecOps Project")
    parser.add_argument("--product-arn", default=None)
    args = parser.parse_args()

    account_id = clean_account_id(args.account_id)
    product_arn = args.product_arn or f"arn:aws:securityhub:{args.region}:{account_id}:product/{account_id}/default"
    normalized = read_json(Path(args.input))
    timestamp = utc_now()

    metadata = {
        "app": normalized.get("app"),
        "environment": normalized.get("environment"),
        "commit": normalized.get("commit"),
        "buildNumber": normalized.get("buildNumber"),
    }

    findings = [
        build_asff_finding(
            finding,
            metadata,
            account_id=account_id,
            region=args.region,
            product_arn=product_arn,
            product_name=args.product_name,
            company_name=args.company_name,
            timestamp=timestamp,
        )
        for finding in normalized.get("findings", [])
    ]

    # ✨ FIX: Output DIRECT ARRAY, not wrapper object
    # AWS Security Hub BatchImportFindings expects an array of ASFF findings
    # NOT: { "schemaVersion": "...", "findings": [...] }
    # YES: [ { "SchemaVersion": "2018-10-08", ... }, ... ]
    
    write_json(Path(args.out), findings)

    print(f"[+] Generated {len(findings)} ASFF findings")
    print(f"[+] Output format: Direct array (compatible with Security Hub BatchImportFindings)")
    print(f"[+] Saved to: {args.out}")
    
    if len(findings) == 0:
        print("[*] No findings generated. Check if normalized report contains any findings.")
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
