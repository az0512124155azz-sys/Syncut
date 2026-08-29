param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ProbeSource,
    [Parameter(Mandatory = $true)][string]$Label
)

$ErrorActionPreference = 'Stop'
$bin = Join-Path $Root 'bin'
$probe = Join-Path $bin 'syncut-kio-probe.exe'
if (-not (Test-Path -LiteralPath $ProbeSource)) { throw "KIO probe executable is missing: $ProbeSource" }
if (-not (Test-Path -LiteralPath (Join-Path $bin 'kioworker.exe'))) { throw "KIO worker is missing from $Label package." }
if (-not (Test-Path -LiteralPath (Join-Path $bin 'kf6\kio\kio_file.dll'))) { throw "KIO file protocol plugin is missing from $Label package." }

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
    $process.WaitForExit()
    $process.Refresh()
    $outText = if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue } else { '' }
    $errText = if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue } else { '' }
    if ($outText) { Write-Host $outText.TrimEnd() }
    if ($errText) { Write-Host $errText.TrimEnd() }
    $combined = "$outText`n$errText"
    if ($combined -match 'Unknown protocol|Unable to create KIO worker|KIO_STAT_FAILED') { throw "$Label KIO worker error was reproduced." }
    if ($combined -notmatch 'KIO_FILE_PROTOCOL_OK') { throw "$Label KIO probe did not confirm the local file protocol." }
    if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) { throw "$Label KIO probe exited with code $($process.ExitCode)." }
    Write-Host "$Label KIO local-file protocol test passed."
} finally {
    $env:PATH = $oldPath
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    Stop-Process -Name 'kioworker' -Force -ErrorAction SilentlyContinue
}
