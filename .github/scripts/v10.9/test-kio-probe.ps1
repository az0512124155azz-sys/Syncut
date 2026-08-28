param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ProbeSource,
    [Parameter(Mandatory = $true)][string]$Label
)

$ErrorActionPreference = 'Stop'
$bin = Join-Path $Root 'bin'
$probe = Join-Path $bin 'syncut-kio-probe.exe'
if (-not (Test-Path -LiteralPath $ProbeSource)) {
    throw "KIO probe executable is missing: $ProbeSource"
}
if (-not (Test-Path -LiteralPath (Join-Path $bin 'kioworker.exe'))) {
    throw "KIO worker is missing from $Label package."
}
if (-not (Test-Path -LiteralPath (Join-Path $bin 'kf6\kio\kio_file.dll'))) {
    throw "KIO file protocol plugin is missing from $Label package."
}

Copy-Item -LiteralPath $ProbeSource -Destination $probe -Force
$stdout = Join-Path $env:GITHUB_WORKSPACE ("kio-probe-$Label-out.log")
$stderr = Join-Path $env:GITHUB_WORKSPACE ("kio-probe-$Label-err.log")
Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue

$oldPath = $env:PATH
$env:PATH = "$bin;$env:SystemRoot\System32;$env:SystemRoot"
try {
    $process = Start-Process -FilePath $probe -WorkingDirectory $bin -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(30000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "$Label KIO probe timed out."
    }

    if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout }
    if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr }

    if ($process.ExitCode -ne 0) {
        throw "$Label KIO probe failed with exit code $($process.ExitCode)."
    }

    $combined = ((Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue) + "`n" +
        (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue))
    if ($combined -notmatch 'KIO_FILE_PROTOCOL_OK') {
        throw "$Label KIO probe did not confirm the local file protocol."
    }
    if ($combined -match 'Unknown protocol|Unable to create KIO worker|KIO_STAT_FAILED') {
        throw "$Label KIO worker error was reproduced."
    }
    Write-Host "$Label KIO local-file protocol test passed."
} finally {
    $env:PATH = $oldPath
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 250
    Stop-Process -Name 'kioworker' -Force -ErrorAction SilentlyContinue
}
