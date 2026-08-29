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
    if (-not (Test-Path -LiteralPath $required)) { throw "$Label runtime directory missing: $required" }
}
if (-not (Test-Path -LiteralPath (Join-Path $profiles 'dv_pal'))) { throw "$Label MLT dv_pal profile missing." }
if (-not (Get-ChildItem -LiteralPath $frei0r -Filter '*.dll' -File -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    throw "$Label Frei0r plugin DLLs are missing."
}

$old = @{
    PATH = $env:PATH
    MLT_PREFIX = $env:MLT_PREFIX
    MLT_REPOSITORY = $env:MLT_REPOSITORY
    MLT_DATA = $env:MLT_DATA
    MLT_PROFILES_PATH = $env:MLT_PROFILES_PATH
    FREI0R_PATH = $env:FREI0R_PATH
}
$env:PATH = "$bin;$env:SystemRoot\System32;$env:SystemRoot"
$env:MLT_PREFIX = $Root
$env:MLT_REPOSITORY = $repo
$env:MLT_DATA = $data
$env:MLT_PROFILES_PATH = $profiles
$env:FREI0R_PATH = $frei0r

function Assert-NativeSuccess {
    param([string]$Name,[scriptblock]$Command)
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Label $Name failed with exit code $LASTEXITCODE." }
}

try {
    $ffmpeg = Join-Path $bin 'ffmpeg.exe'
    $ffprobe = Join-Path $bin 'ffprobe.exe'
    $melt = Join-Path $bin 'melt.exe'
    foreach ($exe in @($ffmpeg,$ffprobe,$melt)) {
        if (-not (Test-Path -LiteralPath $exe)) { throw "$Label tool missing: $exe" }
    }

    Assert-NativeSuccess 'FFmpeg version check' { & $ffmpeg -version }
    Assert-NativeSuccess 'FFprobe version check' { & $ffprobe -version }
    Assert-NativeSuccess 'MLT version check' { & $melt -version }

    $sample = Join-Path $env:GITHUB_WORKSPACE ("syncut-$Label-sample.mp4")
    Remove-Item -LiteralPath $sample -Force -ErrorAction SilentlyContinue
    & $ffmpeg -hide_banner -loglevel error -y `
        -f lavfi -i 'testsrc2=size=640x360:rate=25' `
        -f lavfi -i 'sine=frequency=880:sample_rate=48000' `
        -t 2 -c:v libx264 -pix_fmt yuv420p -c:a aac $sample
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $sample)) { throw "$Label FFmpeg sample render failed." }
    if ((Get-Item -LiteralPath $sample).Length -lt 10000) { throw "$Label rendered sample is unexpectedly small." }

    $probeText = ((& $ffprobe -v error -show_entries 'format=duration' -of json $sample 2>&1) | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "$Label FFprobe inspection failed." }
    $probe = $probeText | ConvertFrom-Json -ErrorAction Stop
    if ($null -eq $probe.format -or [string]::IsNullOrWhiteSpace([string]$probe.format.duration)) {
        throw "$Label FFprobe JSON did not contain format.duration."
    }
    Write-Host "$Label FFprobe duration: $($probe.format.duration)"

    # Process the actual MP4 using MLT and a Frei0r filter. This verifies the
    # module directory, profiles, FFmpeg producer, and dynamically loaded
    # Frei0r plugin together instead of merely checking file names.
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
    $process = Start-Process -FilePath $melt -ArgumentList $args -WorkingDirectory $bin -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $mltOut -RedirectStandardError $mltErr
    $process.Refresh()
    $outText = if (Test-Path -LiteralPath $mltOut) { Get-Content -LiteralPath $mltOut -Raw -ErrorAction SilentlyContinue } else { '' }
    $errText = if (Test-Path -LiteralPath $mltErr) { Get-Content -LiteralPath $mltErr -Raw -ErrorAction SilentlyContinue } else { '' }
    if ($outText) { Write-Host $outText }
    if ($errText) { Write-Host $errText }
    $combined = "$outText`n$errText"
    if ($process.ExitCode -ne 0) { throw "$Label MLT/Frei0r processing failed with exit code $($process.ExitCode)." }
    if ($combined -match '(?i)no plugins found|failed to open properties file|invalid filter|frei0r.*not found|failed to load') {
        throw "$Label MLT/Frei0r runtime logged a loading error."
    }
    Write-Host "$Label FFmpeg, FFprobe, MLT, and Frei0r functional tests passed."
} finally {
    $env:PATH = $old.PATH
    $env:MLT_PREFIX = $old.MLT_PREFIX
    $env:MLT_REPOSITORY = $old.MLT_REPOSITORY
    $env:MLT_DATA = $old.MLT_DATA
    $env:MLT_PROFILES_PATH = $old.MLT_PROFILES_PATH
    $env:FREI0R_PATH = $old.FREI0R_PATH
}
