#!/usr/bin/env python3
"""Validate the private hosted-build workflow template and its PowerShell blocks."""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / "private-build-template" / "build-rag.yml"
PARSER = r"""
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
        fail(f"Template not found: {WORKFLOW}")
    try:
        doc = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        fail(f"Invalid YAML: {exc}")
    if not isinstance(doc, dict):
        fail("Template root must be a mapping.")
    triggers = doc.get("on", doc.get(True, {}))
    if not isinstance(triggers, dict) or "workflow_dispatch" not in triggers:
        fail("Private hosted build must use manual workflow_dispatch.")
    jobs = doc.get("jobs")
    build = jobs.get("build") if isinstance(jobs, dict) else None
    if not isinstance(build, dict) or build.get("runs-on") != "windows-latest":
        fail("Expected a build job on windows-latest.")
    steps = build.get("steps", [])
    if not isinstance(steps, list):
        fail("Build steps must be a list.")
    names = {step.get("name") for step in steps if isinstance(step, dict)}
    for required in (
        "Refuse to run unless this repository is private",
        "Check out private input storage",
        "Check out public RAG source and pinned submodules",
        "Validate private inputs and build paths",
        "Generate native game code and compile RAGSuperstarSaga.exe",
        "Stage portable package without ROM or BIOS",
        "Upload build package to this private repository only",
    ):
        if required not in names:
            fail(f"Missing required workflow step: {required}")
    checkouts = [
        step for step in steps
        if isinstance(step, dict) and str(step.get("uses", "")).startswith("actions/checkout@")
    ]
    if not any(step.get("with", {}).get("repository") == "TotallyJustRetro/rag" for step in checkouts):
        fail("Template must checkout the public RAG source.")
    uploads = [
        step for step in steps
        if isinstance(step, dict) and str(step.get("uses", "")).startswith("actions/upload-artifact@")
    ]
    if len(uploads) != 1:
        fail("Expected exactly one package artifact upload.")
    artifact_path = str(uploads[0].get("with", {}).get("path", ""))
    if "private-inputs/build-output/RAG-Edition" not in artifact_path or ".gba" in artifact_path.lower() or "bios" in artifact_path.lower():
        fail("Artifact path must point only at the staged runnable package, never private source inputs.")
    run_scripts = [
        (idx, step.get("name", f"step-{idx}"), step.get("run", ""))
        for idx, step in enumerate(steps)
        if isinstance(step, dict) and str(step.get("shell", "")).lower() == "pwsh" and step.get("run")
    ]
    if not run_scripts:
        fail("No PowerShell blocks found.")
    pwsh = shutil.which("pwsh")
    if not pwsh:
        fail("PowerShell 7 (pwsh) is required to validate embedded scripts.")
    with tempfile.TemporaryDirectory(prefix="rag-private-template-check-") as temp_dir:
        temp = Path(temp_dir)
        parser_file = temp / "parse-powershell.ps1"
        parser_file.write_text(PARSER, encoding="utf-8")
        for idx, name, script in run_scripts:
            script_file = temp / f"step-{idx}.ps1"
            script_file.write_text(script, encoding="utf-8")
            result = subprocess.run(
                [pwsh, "-NoLogo", "-NoProfile", "-File", str(parser_file), str(script_file)],
                capture_output=True, text=True, check=False,
            )
            if result.returncode:
                print(result.stdout, file=sys.stderr, end="")
                print(result.stderr, file=sys.stderr, end="")
                fail(f"PowerShell syntax failed in: {name}")
            print(f"PASS PowerShell syntax: {name}")
    print(f"PASS YAML structure and {len(run_scripts)} PowerShell blocks: {WORKFLOW.relative_to(ROOT)}")

if __name__ == "__main__":
    main()
