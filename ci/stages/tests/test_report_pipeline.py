from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


STAGES_DIR = Path(__file__).resolve().parents[1]


class ReportPipelineTest(unittest.TestCase):
    def test_normalize_and_generate_asff(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            raw = root / "raw"
            (raw / "secrets").mkdir(parents=True)
            (raw / "sca").mkdir(parents=True)

            (raw / "secrets" / "gitleaks-report.json").write_text(
                json.dumps(
                    [
                        {
                            "RuleID": "generic-api-key",
                            "Description": "Test fixture",
                            "File": "app/example.js",
                            "StartLine": 7,
                            "Fingerprint": "fixture",
                        }
                    ]
                ),
                encoding="utf-8",
            )
            (raw / "sca" / "trivy-sca-report.json").write_text(
                json.dumps(
                    {
                        "ArtifactName": "app",
                        "Results": [
                            {
                                "Target": "package-lock.json",
                                "Vulnerabilities": [
                                    {
                                        "VulnerabilityID": "CVE-2099-0001",
                                        "PkgName": "fixture-package",
                                        "InstalledVersion": "1.0.0",
                                        "FixedVersion": "1.0.1",
                                        "Severity": "HIGH",
                                        "Title": "Fixture vulnerability",
                                    }
                                ],
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            normalized = root / "normalized.json"
            summary = root / "summary.json"
            subprocess.run(
                [
                    sys.executable,
                    str(STAGES_DIR / "normalize-reports.py"),
                    "--raw-dir",
                    str(raw),
                    "--out",
                    str(normalized),
                    "--summary",
                    str(summary),
                    "--app",
                    "tetris",
                    "--env",
                    "test",
                    "--commit",
                    "0123456789abcdef",
                    "--build",
                    "1",
                ],
                check=True,
            )

            normalized_data = json.loads(normalized.read_text(encoding="utf-8"))
            self.assertEqual(normalized_data["summary"]["total"], 2)
            self.assertEqual(normalized_data["summary"]["bySeverity"]["CRITICAL"], 1)
            self.assertEqual(normalized_data["summary"]["bySeverity"]["HIGH"], 1)

            asff = root / "securityhub-asff.json"
            subprocess.run(
                [
                    sys.executable,
                    str(STAGES_DIR / "generate-asff.py"),
                    "--input",
                    str(normalized),
                    "--out",
                    str(asff),
                    "--region",
                    "ap-southeast-1",
                    "--account-id",
                    "123456789012",
                ],
                check=True,
            )

            findings = json.loads(asff.read_text(encoding="utf-8"))
            self.assertEqual(len(findings), 2)
            self.assertTrue(all(item["SchemaVersion"] == "2018-10-08" for item in findings))
            self.assertTrue(all(item["AwsAccountId"] == "123456789012" for item in findings))


if __name__ == "__main__":
    unittest.main()
