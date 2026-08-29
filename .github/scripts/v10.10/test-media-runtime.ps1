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

$env:PATH = "$bin;$env:SystemRoot\System32;$env:SystemRoot"
$env:MLT_PREFIX = $Root

# Current packaged layout.
$repo = Join-Path $Root 'lib\mlt'
$data = Join-Path $Root 'share\mlt'
if (-not (Test-Path -LiteralPath $repo)) { throw "MLT repository missing: $repo" }
if (-not (Test-Path -LiteralPath $data)) { throw "MLT data missing: $data" }
if (-not (Test-Path -LiteralPath (Join-Path $data 'profiles\dv_pal'))) {
    throw 'MLT profile dv_pal is missing from the package.'
}

$env:MLT_REPOSITORY = $repo
$env:MLT_DATA = $data
$env:MLT_PROFILES_PATH = Join-Path $data 'profiles'

try {
    $ffmpeg = Join-Path $bin 'ffmpeg.exe'
    $ffprobe = Join-Path $bin 'ffprobe.exe'
    $melt = Join-Path $bin 'melt.exe'

    foreach ($exe in @($ffmpeg,$ffprobe,$melt)) {
        if (-not (Test-Path -LiteralPath $exe)) {
            throw "Missing packaged tool: $exe"
        }
    }

    & $ffmpeg -version
    if ($LASTEXITCODE -ne 0) { throw "FFmpeg failed: $LASTEXITCODE" }

    & $ffprobe -version
    if ($LASTEXITCODE -ne 0) { throw "FFprobe failed: $LASTEXITCODE" }

    & $melt -version
    if ($LASTEXITCODE -ne 0) { throw "MLT melt failed: $LASTEXITCODE" }

    $sample = Join-Path $env:GITHUB_WORKSPACE 'syncut-ffmpeg-sample.mp4'
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
        throw 'FFmpeg sample render failed.'
    }

    $probeOutput = & $ffprobe -v error -show_entries 'format=duration' -of json $sample 2>&1
    $probeExit = $LASTEXITCODE
    $probeText = ($probeOutput | Out-String).Trim()
    if ($probeExit -ne 0) {
        Write-Host $probeText
        throw "FFprobe inspection failed: $probeExit"
    }

    $probeObject = $probeText | ConvertFrom-Json -ErrorAction Stop
    if ($null -eq $probeObject.format -or [string]::IsNullOrWhiteSpace([string]$probeObject.format.duration)) {
        throw 'FFprobe JSON did not contain format.duration.'
    }

    Write-Host "FFprobe OK. Duration: $($probeObject.format.duration)"
    Write-Host "MLT_REPOSITORY=$env:MLT_REPOSITORY"
    Write-Host "MLT_DATA=$env:MLT_DATA"
    Write-Host "MLT_PROFILES_PATH=$env:MLT_PROFILES_PATH"

    $mltOut = Join-Path $env:GITHUB_WORKSPACE 'melt-functional-out.log'
    $mltErr = Join-Path $env:GITHUB_WORKSPACE 'melt-functional-error.log'
    Remove-Item -LiteralPath $mltOut,$mltErr -Force -ErrorAction SilentlyContinue

    $p = Start-Process `
        -FilePath $melt `
        -ArgumentList @($sample,'-consumer','null','real_time=-1','terminate_on_pause=1') `
        -WorkingDirectory $bin `
        -Wait `
        -PassThru `
        -NoNewWindow `
        -RedirectStandardOutput $mltOut `
        -RedirectStandardError $mltErr

    $p.Refresh()

    if (Test-Path -LiteralPath $mltOut) { Get-Content -LiteralPath $mltOut -Tail 200 }
    if (Test-Path -LiteralPath $mltErr) { Get-Content -LiteralPath $mltErr -Tail 200 }

    if ($p.ExitCode -ne 0) {
        throw "MLT could not process the rendered sample. Exit code: $($p.ExitCode)"
    }

    Write-Host 'FFmpeg, FFprobe, and real MLT media processing tests passed.'
}
finally {
    $env:PATH = $oldPath
    $env:MLT_PREFIX = $oldMltPrefix
    $env:MLT_REPOSITORY = $oldMltRepository
    $env:MLT_DATA = $oldMltData
    $env:MLT_PROFILES_PATH = $oldMltProfilesPath
}
