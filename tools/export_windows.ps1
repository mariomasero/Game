param([string]$Godot = 'godot')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    $version = (& $Godot --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -ne '4.6.2.stable.official.71f334935') {
        throw "Se requiere Godot 4.6.2 oficial; detectado: $version"
    }
    $template = '.local/tools/godot-4.6.2/windows_release_x86_64.exe'
    if (-not (Test-Path -LiteralPath $template)) {
        throw 'Falta la plantilla oficial. Consulta docs/decisions/007-exportacion-windows.md.'
    }
    if ((Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash -ne '3B2D3F99BD640961AAD1A1A200F0F7233B7DE45B02801CE22D3224DC294D93D1') {
        throw 'La plantilla no coincide con la oficial verificada de Godot 4.6.2.'
    }
    $output = Join-Path $projectRoot 'builds/windows'
    $logs = Join-Path $projectRoot '.local/h4-export'
    New-Item -ItemType Directory -Force $output,$logs | Out-Null
    foreach ($operation in @('import','export')) {
        $log = Join-Path $logs ($operation + '.log')
        if ($operation -eq 'import') {
            & $Godot --headless --path $projectRoot --editor --quit --log-file $log
        } else {
            & $Godot --headless --path $projectRoot --export-release 'Windows Desktop' --log-file $log
        }
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'ERROR:|SCRIPT ERROR:' -Quiet)) {
            throw "Falló $operation. Revisa $log"
        }
    }
    Copy-Item -LiteralPath 'docs/distribution/LEEME.txt' -Destination $output
    Copy-Item -LiteralPath 'docs/distribution/licenses' -Destination $output -Recurse -Force
    $files = Get-Item -LiteralPath (Join-Path $output 'Biotech.exe'),(Join-Path $output 'Biotech.pck'),(Join-Path $output 'LEEME.txt')
    $files += Get-ChildItem -LiteralPath (Join-Path $output 'licenses') -File
    $hashes = foreach ($file in $files) {
        '{0}  {1}' -f (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash, $file.FullName.Substring($output.Length + 1)
    }
    $hashes | Set-Content -LiteralPath (Join-Path $output 'SHA256.txt') -Encoding utf8
    Write-Output "Exportado a $output. Comprueba el ejecutable antes de compartirlo."
} finally {
    Pop-Location
}
