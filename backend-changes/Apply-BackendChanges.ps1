param([string]$BackendPath = 'E:\ethioPromo\ethioPromoBackend')
$ErrorActionPreference = 'Stop'
$taskSourceRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$taskBackendRoot = [System.IO.Path]::GetFullPath($BackendPath).TrimEnd('\')
$taskManifest = Get-Content -LiteralPath (Join-Path $taskSourceRoot 'manifest.json') -Raw | ConvertFrom-Json

# Check every destination before applying any changes, preserving concurrent edits.
foreach ($taskFile in $taskManifest) {
    $taskDestination = [System.IO.Path]::GetFullPath((Join-Path $taskBackendRoot $taskFile.path))
    if (-not $taskDestination.StartsWith($taskBackendRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Destination is outside the backend: $taskDestination"
    }
    if (Test-Path -LiteralPath $taskDestination) {
        $taskCurrentHash = (Get-FileHash -LiteralPath $taskDestination -Algorithm SHA256).Hash
        $taskNewHash = (Get-FileHash -LiteralPath (Join-Path $taskSourceRoot $taskFile.path) -Algorithm SHA256).Hash
        if ($taskCurrentHash -ne $taskFile.originalHash -and $taskCurrentHash -ne $taskNewHash) {
            throw "File changed since preparation; review before applying: $taskDestination"
        }
    } elseif ($null -ne $taskFile.originalHash) {
        throw "An original backend file is missing: $taskDestination"
    }
}
foreach ($taskFile in $taskManifest) {
    $taskDestination = Join-Path $taskBackendRoot $taskFile.path
    New-Item -ItemType Directory -Path (Split-Path $taskDestination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $taskSourceRoot $taskFile.path) -Destination $taskDestination -Force
}
Write-Output "Applied $($taskManifest.Count) channel option source and test files to $taskBackendRoot"
