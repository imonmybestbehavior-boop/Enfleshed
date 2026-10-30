param(
    [string]$Python = "python",
    [switch]$RequireStudio
)
$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Push-Location $repoRoot
try {
    & $Python tools/vfx_pipeline/illustrated_fire.py
    if ($LASTEXITCODE -ne 0) { throw "Artwork generation failed" }
    & $Python tools/vfx_pipeline/build_manifest.py
    if ($LASTEXITCODE -ne 0) { throw "Existing asset manifest validation failed" }
    if ($RequireStudio) {
        & $Python tools/vfx_pipeline/audit_assets.py --require-studio
    } else {
        & $Python tools/vfx_pipeline/audit_assets.py
    }
    if ($LASTEXITCODE -ne 0) { throw "VFX validation or Studio release gate failed" }
} finally {
    Pop-Location
}
