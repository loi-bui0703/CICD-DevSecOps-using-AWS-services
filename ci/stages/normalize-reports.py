#!/usr/bin/env python3
"""Normalize raw scanner reports into one DevSecOps findings schema."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SEVERITIES = ("CRITICAL", "HIGH", "MEDIUM", "LOW", "INFORMATIONAL")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_json(path: Path) -> Any:
    if not path.exists() or path.stat().st_size == 0:
        return None
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, sort_keys=False)
        handle.write("\n")


def stable_hash(*parts: Any) -> str:
    material = "|".join("" if part is None else str(part) for part in parts)
    return hashlib.sha256(material.encode("utf-8")).hexdigest()[:24]


def normalize_severity(value: Any, default: str = "INFORMATIONAL") -> str:
    if value is None:
        return default
    text = str(value).upper().strip()
    if text in SEVERITIES:
        return text
    if text in {"INFO", "INFORMATION"}:
        return "INFORMATIONAL"
    if text in {"BLOCKER"}:
        return "CRITICAL"
    if text in {"MAJOR"}:
        return "HIGH"
    if text in {"MINOR"}:
        return "LOW"
    return default


def raw_report_uri(path: Path, raw_dir: Path, report_uri_prefix: str | None) -> str:
    try:
        relative = path.resolve().relative_to(raw_dir.resolve())
    except ValueError:
        relative = Path(path.name)

    if report_uri_prefix:
        return f"{report_uri_prefix.rstrip('/')}/{relative.as_posix()}"
    return f"raw/{relative.as_posix()}"


def make_finding(
    *,
    tool: str,
    category: str,
    severity: str,
    title: str,
    description: str,
    resource_type: str,
    resource: str,
    raw_report: str,
    file: str | None = None,
    line: int | None = None,
    cve: str | None = None,
    cwe: str | None = None,
    remediation: str | None = None,
    references: list[str] | None = None,
    identity: tuple[Any, ...] = (),
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    finding_id = stable_hash(tool, category, *identity)
    return {
        "id": finding_id,
        "tool": tool,
        "category": category,
        "severity": normalize_severity(severity),
        "title": title or "Security finding",
        "description": description or title or "Security finding detected by scanner.",
        "resourceType": resource_type or "other",
        "resource": resource or file or "unknown",
        "file": file,
        "line": line,
        "cve": cve,
        "cwe": cwe,
        "remediation": remediation,
        "references": references or [],
        "rawReport": raw_report,
        "extra": extra or {},
    }


def parse_gitleaks(path: Path, raw_dir: Path, report_uri_prefix: str | None) -> list[dict[str, Any]]:
    data = read_json(path)
    if not data:
        return []

    leaks = data if isinstance(data, list) else data.get("findings", [])
    findings: list[dict[str, Any]] = []
    raw_uri = raw_report_uri(path, raw_dir, report_uri_prefix)

    for leak in leaks:
        rule = leak.get("RuleID") or leak.get("rule") or "gitleaks"
        file_path = leak.get("File") or leak.get("file")
        line = leak.get("StartLine") or leak.get("Line")
        fingerprint = leak.get("Fingerprint") or leak.get("Match") or leak.get("Secret")
        description = leak.get("Description") or f"Potential secret detected by rule {rule}."

        findings.append(
            make_finding(
                tool="gitleaks",
                category="secrets",
                severity="CRITICAL",
                title=f"Secret detected: {rule}",
                description=description,
                resource_type="source_file",
                resource=file_path or rule,
                file=file_path,
                line=line,
                remediation="Remove the secret, rotate the exposed credential, and store it in a secret manager.",
                raw_report=raw_uri,
                identity=(rule, file_path, line, fingerprint),
                extra={
                    "ruleId": rule,
                    "fingerprint": fingerprint,
                    "commit": leak.get("Commit"),
                },
            )
        )

    return findings


def parse_trivy(path: Path, category: str, raw_dir: Path, report_uri_prefix: str | None) -> list[dict[str, Any]]:
    data = read_json(path)
    if not data:
        return []

    tool = "trivy"
    artifact = data.get("ArtifactName") or data.get("ArtifactType") or category
    raw_uri = raw_report_uri(path, raw_dir, report_uri_prefix)
    findings: list[dict[str, Any]] = []

    for result in data.get("Results", []):
        target = result.get("Target") or artifact
        for vuln in result.get("Vulnerabilities", []) or []:
            vuln_id = vuln.get("VulnerabilityID")
            package = vuln.get("PkgName")
            installed = vuln.get("InstalledVersion")
            fixed = vuln.get("FixedVersion")
            title = vuln.get("Title") or f"{vuln_id or 'Vulnerability'} in {package or target}"
            description = vuln.get("Description") or title
            severity = vuln.get("Severity")
            references = vuln.get("References") or []
            primary_url = vuln.get("PrimaryURL")
            if primary_url and primary_url not in references:
                references.insert(0, primary_url)

            remediation = "Upgrade the affected package."
            if fixed:
                remediation = f"Upgrade {package} to fixed version {fixed}."

            findings.append(
                make_finding(
                    tool=tool,
                    category=category,
                    severity=severity,
                    title=title,
                    description=description,
                    resource_type="container_image" if category == "container" else "dependency",
                    resource=package or target,
                    file=target,
                    cve=vuln_id if str(vuln_id or "").startswith("CVE-") else None,
                    remediation=remediation,
                    references=references,
                    raw_report=raw_uri,
                    identity=(category, artifact, target, vuln_id, package, installed),
                    extra={
                        "artifact": artifact,
                        "target": target,
                        "packageName": package,
                        "installedVersion": installed,
                        "fixedVersion": fixed,
                        "vulnerabilityId": vuln_id,
                    },
                )
            )

    return findings


def parse_trivy_sca(path: Path, raw_dir: Path, report_uri_prefix: str | None) -> list[dict[str, Any]]:
    return parse_trivy(path, "sca", raw_dir, report_uri_prefix)


def parse_trivy_container(path: Path, raw_dir: Path, report_uri_prefix: str | None) -> list[dict[str, Any]]:
    return parse_trivy(path, "container", raw_dir, report_uri_prefix)


def _checkov_reports(data: Any) -> list[dict[str, Any]]:
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    if isinstance(data, dict):
        return [data]
    return []


def parse_checkov(path: Path, raw_dir: Path, report_uri_prefix: str | None) -> list[dict[str, Any]]:
    data = read_json(path)
    if not data:
        return []

    raw_uri = raw_report_uri(path, raw_dir, report_uri_prefix)
    findings: list[dict[str, Any]] = []

    for report in _checkov_reports(data):
        results = report.get("results") or {}
        failed_checks = results.get("failed_checks") or []
        for check in failed_checks:
            check_id = check.get("check_id") or check.get("bc_check_id") or "checkov"
            check_name = check.get("check_name") or "IaC misconfiguration"
            file_path = check.get("file_path")
            line_range = check.get("file_line_range") or []
            line = line_range[0] if line_range else None
            resource = check.get("resource") or file_path or check_id
            guideline = check.get("guideline")
            severity = check.get("severity") or "MEDIUM"

            findings.append(
                make_finding(
                    tool="checkov",
                    category="iac",
                    severity=severity,
                    title=f"{check_id}: {check_name}",
                    description=check_name,
                    resource_type="iac_resource",
                    resource=resource,
                    file=file_path,
                    line=line,
                    remediation=guideline or "Review and fix the IaC misconfiguration.",
                    references=[guideline] if guideline else [],
                    raw_report=raw_uri,
                    identity=(check_id, file_path, line, resource),
                    extra={
                        "checkId": check_id,
                        "checkType": report.get("check_type"),
                        "resource": resource,
                    },
                )
            )

    return findings


def zap_severity(alert: dict[str, Any]) -> str:
    riskcode = str(alert.get("riskcode", "")).strip()
    if riskcode == "3":
        return "HIGH"
    if riskcode == "2":
        return "MEDIUM"
    if riskcode == "1":
        return "LOW"
    if riskcode == "0":
        return "INFORMATIONAL"
    riskdesc = str(alert.get("riskdesc", "")).split(" ", 1)[0]
    return normalize_severity(riskdesc)


def parse_zap(path: Path, raw_dir: Path, report_uri_prefix: str | None) -> list[dict[str, Any]]:
    data = read_json(path)
    if not data:
        return []

    sites = data.get("site") or []
    if isinstance(sites, dict):
        sites = [sites]

    raw_uri = raw_report_uri(path, raw_dir, report_uri_prefix)
    findings: list[dict[str, Any]] = []

    for site in sites:
        site_name = site.get("@name") or site.get("name") or "zap-target"
        for alert in site.get("alerts", []) or []:
            plugin_id = alert.get("pluginid") or alert.get("alertRef") or "zap"
            alert_name = alert.get("alert") or alert.get("name") or "OWASP ZAP alert"
            instances = alert.get("instances") or [{}]
            cwe = alert.get("cweid")
            references = []
            if alert.get("reference"):
                references.append(str(alert.get("reference")))

            for instance in instances:
                uri = instance.get("uri") or site_name
                method = instance.get("method")
                param = instance.get("param")
                evidence = instance.get("evidence")

                findings.append(
                    make_finding(
                        tool="owasp-zap",
                        category="dast",
                        severity=zap_severity(alert),
                        title=alert_name,
                        description=alert.get("desc") or alert_name,
                        resource_type="url",
                        resource=uri,
                        cwe=f"CWE-{cwe}" if cwe and str(cwe) != "-1" else None,
                        remediation=alert.get("solution") or "Review the ZAP finding and apply the recommended fix.",
                        references=references,
                        raw_report=raw_uri,
                        identity=(plugin_id, uri, method, param, evidence),
                        extra={
                            "pluginId": plugin_id,
                            "method": method,
                            "param": param,
                            "confidence": alert.get("confidence"),
                            "riskCode": alert.get("riskcode"),
                        },
                    )
                )

    return findings


def sonar_issue_severity(issue: dict[str, Any]) -> str:
    impacts = issue.get("impacts") or []
    for impact in impacts:
        severity = impact.get("severity")
        if severity:
            return normalize_severity(severity)
    return normalize_severity(issue.get("severity"))


def parse_sonar(path: Path, raw_dir: Path, report_uri_prefix: str | None) -> list[dict[str, Any]]:
    data = read_json(path)
    if not data:
        return []

    issues = data.get("issues") if isinstance(data, dict) else []
    raw_uri = raw_report_uri(path, raw_dir, report_uri_prefix)
    findings: list[dict[str, Any]] = []

    for issue in issues or []:
        issue_key = issue.get("key")
        rule = issue.get("rule")
        component = issue.get("component")
        line = issue.get("line")
        message = issue.get("message") or "SonarQube issue"
        issue_type = issue.get("type")

        findings.append(
            make_finding(
                tool="sonarqube",
                category="sast",
                severity=sonar_issue_severity(issue),
                title=f"{rule or 'sonarqube'}: {message}",
                description=message,
                resource_type="source_file",
                resource=component or rule or issue_key,
                file=component,
                line=line,
                remediation="Review the SonarQube rule and fix the affected source code.",
                raw_report=raw_uri,
                identity=(issue_key, rule, component, line, message),
                extra={
                    "issueKey": issue_key,
                    "rule": rule,
                    "type": issue_type,
                    "status": issue.get("status"),
                },
            )
        )

    return findings


def summarize(findings: list[dict[str, Any]], missing_reports: list[str]) -> dict[str, Any]:
    by_severity = {severity: 0 for severity in SEVERITIES}
    by_category: dict[str, int] = {}
    by_tool: dict[str, int] = {}

    for finding in findings:
        by_severity[finding["severity"]] = by_severity.get(finding["severity"], 0) + 1
        by_category[finding["category"]] = by_category.get(finding["category"], 0) + 1
        by_tool[finding["tool"]] = by_tool.get(finding["tool"], 0) + 1

    return {
        "total": len(findings),
        "bySeverity": by_severity,
        "byCategory": by_category,
        "byTool": by_tool,
        "missingReports": missing_reports,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Normalize DevSecOps raw scanner reports.")
    parser.add_argument("--raw-dir", required=True, help="Directory containing raw scanner reports.")
    parser.add_argument("--out", required=True, help="Output normalized findings JSON path.")
    parser.add_argument("--summary", required=True, help="Output summary JSON path.")
    parser.add_argument("--app", required=True)
    parser.add_argument("--env", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--report-uri-prefix", default=None, help="Optional S3 prefix for raw report links.")
    args = parser.parse_args()

    raw_dir = Path(args.raw_dir)
    report_uri_prefix = args.report_uri_prefix

    report_specs = [
        ("secrets/gitleaks-report.json", parse_gitleaks),
        ("sca/trivy-sca-report.json", parse_trivy_sca),
        ("container/trivy-container-report.json", parse_trivy_container),
        ("iac/checkov-report.json", parse_checkov),
        ("dast/zap-report.json", parse_zap),
        ("sast/sonar-issues.json", parse_sonar),
    ]

    findings: list[dict[str, Any]] = []
    missing_reports: list[str] = []

    for relative_path, parser_func in report_specs:
        report_path = raw_dir / relative_path
        if not report_path.exists():
            missing_reports.append(relative_path)
            continue
        findings.extend(parser_func(report_path, raw_dir, report_uri_prefix))

    summary = summarize(findings, missing_reports)
    normalized = {
        "schemaVersion": "devsecops-findings/v1",
        "generatedAt": utc_now(),
        "app": args.app,
        "environment": args.env,
        "commit": args.commit,
        "buildNumber": args.build,
        "summary": summary,
        "findings": findings,
    }

    write_json(Path(args.out), normalized)
    write_json(
        Path(args.summary),
        {
            "schemaVersion": "devsecops-summary/v1",
            "generatedAt": normalized["generatedAt"],
            "app": args.app,
            "environment": args.env,
            "commit": args.commit,
            "buildNumber": args.build,
            **summary,
        },
    )

    print(f"[+] Normalized {len(findings)} findings into {args.out}")
    if missing_reports:
        print(f"[*] Missing raw reports: {', '.join(missing_reports)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
