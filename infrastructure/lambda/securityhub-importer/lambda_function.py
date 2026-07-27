"""Import pre-generated ASFF findings from S3 into AWS Security Hub."""

from __future__ import annotations

import json
import logging
import os
import urllib.parse
from typing import Any

import boto3


LOG = logging.getLogger()
LOG.setLevel(logging.INFO)

S3 = boto3.client("s3")
SECURITYHUB = boto3.client("securityhub", region_name=os.getenv("SECURITYHUB_REGION"))
ASFF_SUFFIX = os.getenv("ASFF_SUFFIX", "asff/securityhub-asff.json")


def chunks(items: list[dict[str, Any]], size: int) -> list[list[dict[str, Any]]]:
    return [items[index : index + size] for index in range(0, len(items), size)]


def load_findings(bucket: str, key: str) -> list[dict[str, Any]]:
    response = S3.get_object(Bucket=bucket, Key=key)
    payload = json.loads(response["Body"].read())

    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        return payload.get("findings", [])
    return []


def import_findings(findings: list[dict[str, Any]]) -> dict[str, int]:
    imported = 0
    failed = 0

    for batch in chunks(findings, 100):
        result = SECURITYHUB.batch_import_findings(Findings=batch)
        imported += len(batch) - int(result.get("FailedCount", 0))
        failed += int(result.get("FailedCount", 0))
        if result.get("FailedFindings"):
            LOG.warning("Security Hub failed findings: %s", result["FailedFindings"])

    return {"imported": imported, "failed": failed}


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    processed = 0
    imported = 0
    failed = 0
    skipped = 0

    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        if not key.endswith(ASFF_SUFFIX):
            LOG.info("Skipping non-ASFF object: s3://%s/%s", bucket, key)
            skipped += 1
            continue

        findings = load_findings(bucket, key)
        LOG.info("Loaded %s findings from s3://%s/%s", len(findings), bucket, key)

        result = import_findings(findings)
        processed += 1
        imported += result["imported"]
        failed += result["failed"]

    if failed:
        raise RuntimeError(f"Security Hub import failed for {failed} findings")

    return {
        "processedObjects": processed,
        "importedFindings": imported,
        "failedFindings": failed,
        "skippedObjects": skipped,
    }
