param(
    [Parameter(Mandatory = $true)][string]$Root
)

$ErrorActionPreference = 'Stop'

$bin = Join-Path $Root 'bin'
$oldPath = $env:PATH
$oldMltPrefix = $env:MLT_PREFIX
$oldMltRepository = $env:MLT_REPOSITORY
$oldMltData = $env:MLT_DATA

$env:PATH = "$bin;$env:SystemRoot\System32;$env:SystemRoot"
$env:MLT_PREFIX = $Root
$env:MLT_REPOSITORY = Join-Path $Root 'lib\mlt-7'
$env:MLT_DATA = Join-Path $Root 'share\mlt-7'

function Invoke-CheckedTool {
    param(
        [Parameter(Mandatory = $true)][string]$Exe,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-Path -LiteralPath $Exe)) {
        throw "Packaged tool is missing: $Name"
    }

    Write-Host "Testing packaged $Name..."
    $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -WorkingDirectory $bin -Wait -PassThru -NoNewWindow
    $p.Refresh()
    if ($p.ExitCode -ne 0) {
        throw "Packaged $Name failed with exit code $($p.ExitCode)."
    }
}

try {
    $ffmpeg = Join-Path $bin 'ffmpeg.exe'
    $ffprobe = Join-Path $bin 'ffprobe.exe'
    $meltExe = Join-Path $bin 'melt.exe'

    Invoke-CheckedTool -Exe $ffmpeg -Arguments @('-version') -Name 'ffmpeg.exe'
    Invoke-CheckedTool -Exe $ffprobe -Arguments @('-version') -Name 'ffprobe.exe'
    Invoke-CheckedTool -Exe $meltExe -Arguments @('-version') -Name 'melt.exe'

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
    $ffprobeExit = $LASTEXITCODE
    $probeText = ($probeOutput | Out-String).Trim()

    if ($ffprobeExit -ne 0) {
        Write-Host $probeText
        throw "FFprobe could not inspect the rendered sample. Exit code: $ffprobeExit"
    }

    if ([string]::IsNullOrWhiteSpace($probeText)) {
        throw 'FFprobe returned empty output.'
    }

    $probeObject = $probeText | ConvertFrom-Json -ErrorAction Stop

    if ($null -eq $probeObject.format -or [string]::IsNullOrWhiteSpace([string]$probeObject.format.duration)) {
        Write-Host $probeText
        throw 'FFprobe JSON did not contain format.duration.'
    }

    Write-Host "FFprobe OK. Duration: $($probeObject.format.duration)"

    $queryOut = Join-Path $env:GITHUB_WORKSPACE 'melt-query.log'
    $queryErr = Join-Path $env:GITHUB_WORKSPACE 'melt-query-error.log'
    Remove-Item -LiteralPath $queryOut,$queryErr -Force -ErrorAction SilentlyContinue

    $melt = Start-Process -FilePath $meltExe `
        -ArgumentList @('-query','producers') `
        -WorkingDirectory $bin `
        -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $queryOut `
        -RedirectStandardError $queryErr

    $melt.Refresh()

    if ($melt.ExitCode -ne 0) {
        throw "MLT producer query failed with exit code $($melt.ExitCode)."
    }

    $queryText = ((Get-Content -LiteralPath $queryOut -Raw -ErrorAction SilentlyContinue) + "`n" +
        (Get-Content -LiteralPath $queryErr -Raw -ErrorAction SilentlyContinue))

    if ($queryText -notmatch '(?i)avformat|color') {
        throw 'MLT did not expose expected producers.'
    }

    Write-Host 'FFmpeg, FFprobe, and MLT runtime tests passed.'
}
finally {
    $env:PATH = $oldPath
    $env:MLT_PREFIX = $oldMltPrefix
    $env:MLT_REPOSITORY = $oldMltRepository
    $env:MLT_DATA = $oldMltData
}
