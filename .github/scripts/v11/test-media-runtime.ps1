param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Label
)

$ErrorActionPreference = 'Stop'

$bin = Join-Path $Root 'bin'
$repo = Join-Path $Root 'lib\mlt'
$data = Join-Path $Root 'share\mlt'
$profiles = Join-Path $data 'profiles'
$frei0r = Join-Path $Root 'lib\frei0r-1'

foreach ($required in @($bin,$repo,$data,$profiles,$frei0r)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "$Label runtime directory missing: $required"
    }
}

$old = @{
    PATH              = $env:PATH
    MLT_PREFIX        = $env:MLT_PREFIX
    MLT_REPOSITORY    = $env:MLT_REPOSITORY
    MLT_DATA          = $env:MLT_DATA
    MLT_PROFILES_PATH = $env:MLT_PROFILES_PATH
    FREI0R_PATH       = $env:FREI0R_PATH
}

$env:PATH = "$bin;$env:SystemRoot\System32;$env:SystemRoot"
$env:MLT_PREFIX = $Root
$env:MLT_REPOSITORY = $repo
$env:MLT_DATA = $data
$env:MLT_PROFILES_PATH = $profiles
$env:FREI0R_PATH = $frei0r

try {
    $ffmpeg = Join-Path $bin 'ffmpeg.exe'
    $ffprobe = Join-Path $bin 'ffprobe.exe'
    $melt = Join-Path $bin 'melt.exe'

    foreach ($exe in @($ffmpeg,$ffprobe,$melt)) {
        if (-not (Test-Path -LiteralPath $exe)) {
            throw "$Label tool missing: $exe"
        }
    }

    & $melt -version
    if ($LASTEXITCODE -ne 0) {
        throw "$Label MLT version check failed."
    }

    # Force complete repository initialization before GUI smoke testing.
    $queryOut = Join-Path $env:GITHUB_WORKSPACE ("melt-$Label-query-out.log")
    $queryErr = Join-Path $env:GITHUB_WORKSPACE ("melt-$Label-query-error.log")
    Remove-Item -LiteralPath $queryOut,$queryErr -Force -ErrorAction SilentlyContinue

    $query = Start-Process `
        -FilePath $melt `
        -ArgumentList @('-query') `
        -WorkingDirectory $bin `
        -Wait `
        -PassThru `
        -NoNewWindow `
        -RedirectStandardOutput $queryOut `
        -RedirectStandardError $queryErr

    $query.Refresh()

    $queryStdout = if (Test-Path -LiteralPath $queryOut) {
        Get-Content -LiteralPath $queryOut -Raw -ErrorAction SilentlyContinue
    } else { '' }

    $queryStderr = if (Test-Path -LiteralPath $queryErr) {
        Get-Content -LiteralPath $queryErr -Raw -ErrorAction SilentlyContinue
    } else { '' }

    $queryCombined = "$queryStdout`n$queryStderr"

    if ($queryStdout) { Write-Host $queryStdout }
    if ($queryStderr) { Write-Host $queryStderr }

    if ($query.ExitCode -ne 0) {
        throw "$Label MLT repository query failed with exit code $($query.ExitCode)."
    }

    if ($queryCombined -match '(?i)failed to dlopen|specified module could not be found|no plugins found|failed to open properties file') {
        throw "$Label MLT repository contains unloadable modules."
    }

    $sample = Join-Path $env:GITHUB_WORKSPACE ("syncut-$Label-sample.mp4")
    Remove-Item -LiteralPath $sample -Force -ErrorAction SilentlyContinue

    & $ffmpeg `
        -hide_banner `
        -loglevel error `
        -y `
        -f lavfi `
        -i 'testsrc2=size=640x360:rate=25' `
        -f lavfi `
        -i 'sine=frequency=880:sample_rate=48000' `
        -t 2 `
        -c:v libx264 `
        -pix_fmt yuv420p `
        -c:a aac `
        $sample

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $sample)) {
        throw "$Label FFmpeg sample render failed."
    }

    $probeText = ((& $ffprobe -v error -show_entries 'format=duration' -of json $sample 2>&1) | Out-String).Trim()

    if ($LASTEXITCODE -ne 0) {
        throw "$Label FFprobe inspection failed."
    }

    $probe = $probeText | ConvertFrom-Json -ErrorAction Stop
    if ($null -eq $probe.format -or [string]::IsNullOrWhiteSpace([string]$probe.format.duration)) {
        throw "$Label FFprobe JSON did not contain format.duration."
    }

    $mltOut = Join-Path $env:GITHUB_WORKSPACE ("melt-$Label-out.log")
    $mltErr = Join-Path $env:GITHUB_WORKSPACE ("melt-$Label-error.log")
    Remove-Item -LiteralPath $mltOut,$mltErr -Force -ErrorAction SilentlyContinue

    $args = @(
        $sample,
        'in=0',
        'out=25',
        '-filter',
        'frei0r.brightness',
        'brightness=0.15',
        '-consumer',
        'null',
        'real_time=-1',
        'terminate_on_pause=1'
    )

    $process = Start-Process `
        -FilePath $melt `
        -ArgumentList $args `
        -WorkingDirectory $bin `
        -Wait `
        -PassThru `
        -NoNewWindow `
        -RedirectStandardOutput $mltOut `
        -RedirectStandardError $mltErr

    $process.Refresh()

    $outText = if (Test-Path -LiteralPath $mltOut) {
        Get-Content -LiteralPath $mltOut -Raw -ErrorAction SilentlyContinue
    } else { '' }

    $errText = if (Test-Path -LiteralPath $mltErr) {
        Get-Content -LiteralPath $mltErr -Raw -ErrorAction SilentlyContinue
    } else { '' }

    $combined = "$outText`n$errText"

    if ($outText) { Write-Host $outText }
    if ($errText) { Write-Host $errText }

    if ($process.ExitCode -ne 0) {
        throw "$Label MLT/Frei0r processing failed with exit code $($process.ExitCode)."
    }

    if ($combined -match '(?i)failed to dlopen|specified module could not be found|no plugins found|failed to open properties file|invalid filter|frei0r.*not found|failed to load') {
        throw "$Label MLT/Frei0r runtime logged a loading error."
    }

    Write-Host "$Label complete MLT repository and media processing tests passed."
}
finally {
    foreach ($key in $old.Keys) {
        if ($null -eq $old[$key]) {
            Remove-Item -Path ("Env:" + $key) -ErrorAction SilentlyContinue
        }
        else {
            Set-Item -Path ("Env:" + $key) -Value $old[$key]
        }
    }
}
