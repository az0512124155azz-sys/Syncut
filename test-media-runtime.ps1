param(
    [Parameter(Mandatory = $true)][string]$Root
)

$ErrorActionPreference = 'Stop'

$bin = Join-Path $Root 'bin'
$oldPath = $env:PATH
$oldMltPrefix = $env:MLT_PREFIX
$oldMltRepository = $env:MLT_REPOSITORY
$oldMltData = $env:MLT_DATA
$oldMltProfilesPath = $env:MLT_PROFILES_PATH
$oldFrei0rPath = $env:FREI0R_PATH

$env:PATH = "$bin;$env:SystemRoot\System32;$env:SystemRoot"
$env:MLT_PREFIX = $Root
$env:MLT_REPOSITORY = Join-Path $Root 'lib\mlt'
$env:MLT_DATA = Join-Path $Root 'share\mlt'
$env:MLT_PROFILES_PATH = Join-Path $env:MLT_DATA 'profiles'
$env:FREI0R_PATH = Join-Path $Root 'lib\frei0r-1'

try {
    foreach ($required in @(
        $env:MLT_REPOSITORY,
        $env:MLT_DATA,
        $env:MLT_PROFILES_PATH,
        $env:FREI0R_PATH,
        (Join-Path $env:MLT_PROFILES_PATH 'dv_pal'),
        (Join-Path $env:FREI0R_PATH 'brightness.dll')
    )) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Missing media runtime path: $required" }
    }

    $ffmpeg = Join-Path $bin 'ffmpeg.exe'
    $ffprobe = Join-Path $bin 'ffprobe.exe'
    $melt = Join-Path $bin 'melt.exe'
    foreach ($exe in @($ffmpeg,$ffprobe,$melt)) {
        if (-not (Test-Path -LiteralPath $exe)) { throw "Missing packaged tool: $exe" }
    }

    & $ffmpeg -version
    if ($LASTEXITCODE -ne 0) { throw "FFmpeg failed: $LASTEXITCODE" }
    & $ffprobe -version
    if ($LASTEXITCODE -ne 0) { throw "FFprobe failed: $LASTEXITCODE" }
    & $melt -version
    if ($LASTEXITCODE -ne 0) { throw "MLT melt failed: $LASTEXITCODE" }

    $sample = Join-Path $env:GITHUB_WORKSPACE 'syncut-ffmpeg-sample.mp4'
    Remove-Item -LiteralPath $sample -Force -ErrorAction SilentlyContinue
    & $ffmpeg -hide_banner -loglevel error -y `
        -f lavfi -i 'testsrc2=size=640x360:rate=25' `
        -f lavfi -i 'sine=frequency=880:sample_rate=48000' `
        -t 2 -c:v libx264 -pix_fmt yuv420p -c:a aac $sample
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $sample)) { throw 'FFmpeg sample render failed.' }

    $probeOutput = & $ffprobe -v error -show_entries 'format=duration' -of json $sample 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'FFprobe inspection failed.' }
    $probeObject = (($probeOutput | Out-String).Trim()) | ConvertFrom-Json -ErrorAction Stop
    if ($null -eq $probeObject.format -or [string]::IsNullOrWhiteSpace([string]$probeObject.format.duration)) {
        throw 'FFprobe JSON did not contain format.duration.'
    }
    Write-Host "FFprobe OK. Duration: $($probeObject.format.duration)"

    function Invoke-MeltTest {
        param([string[]]$Arguments, [string]$Label)
        $out = Join-Path $env:GITHUB_WORKSPACE ("melt-$Label-out.log")
        $err = Join-Path $env:GITHUB_WORKSPACE ("melt-$Label-error.log")
        Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
        $p = Start-Process -FilePath $melt -ArgumentList $Arguments -WorkingDirectory $bin -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $out -RedirectStandardError $err
        $p.Refresh()
        if (Test-Path -LiteralPath $out) { Get-Content -LiteralPath $out -Tail 200 }
        if (Test-Path -LiteralPath $err) { Get-Content -LiteralPath $err -Tail 200 }
        if ($p.ExitCode -ne 0) { throw "MLT $Label test failed with exit code $($p.ExitCode)." }
    }

    # Real MLT decode/processing test.
    Invoke-MeltTest -Label 'base' -Arguments @($sample,'-consumer','null','real_time=-1','terminate_on_pause=1')

    # Real Frei0r discovery/processing test. This proves the warning shown by the
    # stock first-run wizard cannot be caused by a missing packaged Frei0r tree.
    Invoke-MeltTest -Label 'frei0r' -Arguments @($sample,'-filter','frei0r.brightness','-consumer','null','real_time=-1','terminate_on_pause=1')

    Write-Host 'FFmpeg, FFprobe, MLT and Frei0r functional tests passed.'
}
finally {
    $env:PATH = $oldPath
    $env:MLT_PREFIX = $oldMltPrefix
    $env:MLT_REPOSITORY = $oldMltRepository
    $env:MLT_DATA = $oldMltData
    $env:MLT_PROFILES_PATH = $oldMltProfilesPath
    $env:FREI0R_PATH = $oldFrei0rPath
}
