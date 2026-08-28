param(
    [Parameter(Mandatory = $true)][string]$Root
)

$ErrorActionPreference = 'Stop'
$bin = Join-Path $Root 'bin'
$oldPath = $env:PATH
$env:PATH = "$bin;$env:SystemRoot\System32;$env:SystemRoot"
$env:MLT_PREFIX = $Root
$env:MLT_REPOSITORY = Join-Path $Root 'lib\mlt-7'
$env:MLT_DATA = Join-Path $Root 'share\mlt-7'

try {
    $tools = @(
        @{ Name = 'ffmpeg.exe'; Args = @('-version') },
        @{ Name = 'ffprobe.exe'; Args = @('-version') },
        @{ Name = 'melt.exe'; Args = @('-version') }
    )
    foreach ($tool in $tools) {
        $exe = Join-Path $bin $tool.Name
        if (-not (Test-Path -LiteralPath $exe)) {
            throw "Packaged tool is missing: $($tool.Name)"
        }
        Write-Host "Testing packaged $($tool.Name)..."
        $process = Start-Process -FilePath $exe -ArgumentList $tool.Args -WorkingDirectory $bin -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {
            throw "Packaged $($tool.Name) failed with exit code $($process.ExitCode)."
        }
    }

    $sample = Join-Path $env:GITHUB_WORKSPACE 'syncut-ffmpeg-sample.mp4'
    & (Join-Path $bin 'ffmpeg.exe') -hide_banner -loglevel error -y `
        -f lavfi -i 'testsrc2=size=640x360:rate=25' `
        -f lavfi -i 'sine=frequency=880:sample_rate=48000' `
        -t 2 -c:v libx264 -pix_fmt yuv420p -c:a aac $sample
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $sample)) {
        throw 'FFmpeg sample render failed.'
    }

    $probeJson = & (Join-Path $bin 'ffprobe.exe') -v error -show_entries format=duration -of json $sample
    if ($LASTEXITCODE -ne 0 -or $probeJson -notmatch 'duration') {
        throw 'FFprobe could not inspect the rendered sample.'
    }

    $queryOut = Join-Path $env:GITHUB_WORKSPACE 'melt-query.log'
    $queryErr = Join-Path $env:GITHUB_WORKSPACE 'melt-query-error.log'
    Remove-Item -LiteralPath $queryOut,$queryErr -Force -ErrorAction SilentlyContinue
    $melt = Start-Process -FilePath (Join-Path $bin 'melt.exe') `
        -ArgumentList @('-query','producers') `
        -WorkingDirectory $bin `
        -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $queryOut `
        -RedirectStandardError $queryErr

    if (Test-Path -LiteralPath $queryOut) { Get-Content -LiteralPath $queryOut -Tail 200 }
    if (Test-Path -LiteralPath $queryErr) { Get-Content -LiteralPath $queryErr -Tail 200 }
    if ($melt.ExitCode -ne 0) {
        throw "MLT producer query failed with exit code $($melt.ExitCode)."
    }

    $queryText = ((Get-Content -LiteralPath $queryOut -Raw -ErrorAction SilentlyContinue) + "`n" +
        (Get-Content -LiteralPath $queryErr -Raw -ErrorAction SilentlyContinue))
    if ($queryText -notmatch 'avformat|color') {
        throw 'MLT did not expose expected producers.'
    }

    Write-Host 'FFmpeg, FFprobe, and MLT runtime tests passed.'
} finally {
    $env:PATH = $oldPath
}
