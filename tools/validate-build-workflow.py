#!/usr/bin/env python3
"""Validate the private Windows build workflow and its embedded PowerShell scripts.

The workflow is manual-only and intentionally does not upload ROM/BIOS-derived
artifacts. This check catches malformed YAML and PowerShell syntax before a user
tries to run the self-hosted build.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "build-rag-edition.yml"
POWERSHELL_PARSER = r"""
param([Parameter(Mandatory = $true)][string]$Path)
$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    $Path, [ref]$tokens, [ref]$parseErrors
) | Out-Null
if ($parseErrors.Count -gt 0) {
    $parseErrors | ForEach-Object {
        Write-Error ("Line {0}: {1}" -f $_.Extent.StartLineNumber, $_.Message)
    }
    exit 1
}
"""


def fail(message: str) -> "NoReturn":
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if not WORKFLOW.is_file():
        fail(f"Workflow not found: {WORKFLOW}")

    try:
        document = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        fail(f"Invalid YAML: {exc}")

    if not isinstance(document, dict):
        fail("Workflow root must be a mapping.")
    jobs = document.get("jobs")
    if not isinstance(jobs, dict) or not isinstance(jobs.get("build"), dict):
        fail("Expected the build job in build-rag-edition.yml.")

    # PyYAML's YAML 1.1 resolver treats unquoted 'on' as True; accept either key.
    triggers = document.get("on", document.get(True, {}))
    if not isinstance(triggers, dict) or "workflow_dispatch" not in triggers:
        fail("The game-specific workflow must be manual-only (workflow_dispatch).")

    inputs = triggers["workflow_dispatch"].get("inputs", {})
    for required_input in ("rom_path", "bios_path", "toolchain_root", "sdl_root", "output_dir"):
        if required_input not in inputs:
            fail(f"Missing workflow input: {required_input}")

    pwsh = shutil.which("pwsh")
    if not pwsh:
        fail("PowerShell 7 (pwsh) is required to validate workflow script blocks.")

    steps = jobs["build"].get("steps", [])
    scripts = [
        (index, step.get("name", f"step-{index}"), step.get("run", ""))
        for index, step in enumerate(steps)
        if step.get("shell", "").lower() == "pwsh" and step.get("run")
    ]
    if not scripts:
        fail("No embedded PowerShell steps were found to validate.")

    with tempfile.TemporaryDirectory(prefix="rag-workflow-check-") as temp_dir:
        temp = Path(temp_dir)
        parser_file = temp / "parse-powershell.ps1"
        parser_file.write_text(POWERSHELL_PARSER, encoding="utf-8")
        for index, name, script in scripts:
            script_file = temp / f"step-{index}.ps1"
            script_file.write_text(script, encoding="utf-8")
            result = subprocess.run(
                [pwsh, "-NoLogo", "-NoProfile", "-File", str(parser_file), str(script_file)],
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode != 0:
                print(result.stdout, file=sys.stderr, end="")
                print(result.stderr, file=sys.stderr, end="")
                fail(f"PowerShell syntax failed in workflow step: {name}")
            print(f"PASS PowerShell syntax: {name}")

    print(f"PASS YAML and {len(scripts)} embedded PowerShell blocks: {WORKFLOW.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
