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
    $process = Start-Process `
        -FilePath $probe `
        -WorkingDirectory $bin `
        -PassThru `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr

    $finished = $process.WaitForExit(30000)
    if (-not $finished) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "$Label KIO probe timed out."
    }

    # Important on Windows PowerShell/.NET when stdout/stderr are redirected:
    # complete async stream draining and refresh the process object before
    # reading ExitCode. The previous test read ExitCode too early and got null.
    $process.WaitForExit()
    $process.Refresh()

    $outText = ''
    $errText = ''
    if (Test-Path -LiteralPath $stdout) {
        $outText = Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue
        if ($outText) { Write-Host $outText.TrimEnd() }
    }
    if (Test-Path -LiteralPath $stderr) {
        $errText = Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue
        if ($errText) { Write-Host $errText.TrimEnd() }
    }

    $combined = "$outText`n$errText"

    # Functional result is authoritative. If KIO actually reported success,
    # do not fail because PowerShell returned a temporarily unavailable
    # ExitCode property.
    if ($combined -match 'Unknown protocol|Unable to create KIO worker|KIO_STAT_FAILED') {
        throw "$Label KIO worker error was reproduced."
    }
    if ($combined -notmatch 'KIO_FILE_PROTOCOL_OK') {
        $exitText = if ($null -eq $process.ExitCode) { '<unavailable>' } else { [string]$process.ExitCode }
        throw "$Label KIO probe did not confirm the local file protocol. Exit code: $exitText"
    }

    if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
        throw "$Label KIO probe reported success text but exited with code $($process.ExitCode)."
    }

    Write-Host "$Label KIO local-file protocol test passed."
}
finally {
    $env:PATH = $oldPath
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 250
    Stop-Process -Name 'kioworker' -Force -ErrorAction SilentlyContinue
}
