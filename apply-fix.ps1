$ErrorActionPreference = 'Stop'
Write-Host 'Syncut v10.12 - runtime + branding + Frei0r + icon fix'
$repo = 'https://github.com/az0512124155azz-sys/Syncut.git'
$work = Join-Path $env:TEMP ('Syncut-v10.12-' + [guid]::NewGuid().ToString('N'))

git clone $repo $work
if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
Set-Location $work
git checkout main
git pull --ff-only origin main
if ($LASTEXITCODE -ne 0) { throw 'git pull failed' }

$replace = @(
  '.github\scripts\v10.10\validate-source.ps1',
  '.github\scripts\v10.10\deploy-runtime.sh',
  '.github\scripts\v10.10\test-media-runtime.ps1',
  '.github\scripts\v10.10\test-gui.ps1',
  'installer.nsi'
)
foreach ($rel in $replace) {
    $src = Join-Path $PSScriptRoot $rel
    $dst = Join-Path $work $rel
    if (-not (Test-Path -LiteralPath $src)) { throw "Patch file missing: $rel" }
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

# Parse all PowerShell files before push.
Get-ChildItem '.github\scripts\v10.10' -Filter '*.ps1' -File | ForEach-Object {
    $null = [scriptblock]::Create([System.IO.File]::ReadAllText($_.FullName))
}

$bash = 'C:\Program Files\Git\bin\bash.exe'
if (Test-Path -LiteralPath $bash) {
    & $bash -n '.github/scripts/v10.10/deploy-runtime.sh'
    if ($LASTEXITCODE -ne 0) { throw 'deploy-runtime.sh syntax error' }
}

git add .github/scripts/v10.10/validate-source.ps1 .github/scripts/v10.10/deploy-runtime.sh .github/scripts/v10.10/test-media-runtime.ps1 .github/scripts/v10.10/test-gui.ps1 installer.nsi
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host 'Fix already present; nothing to push.'; exit 0 }

git commit -m 'Fix Syncut first-run branding MLT Frei0r runtime and Windows icon'
if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
git push origin main
if ($LASTEXITCODE -ne 0) { throw 'git push failed' }
Write-Host ''
Write-Host 'DONE. Build should start automatically.'
Write-Host 'https://github.com/az0512124155azz-sys/Syncut/actions'
