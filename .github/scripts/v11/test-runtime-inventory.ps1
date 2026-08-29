param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Label
)

$ErrorActionPreference = 'Stop'
$bin = Join-Path $Root 'bin'
$required = @(
    'bin\syncut.exe',
    'bin\kdenlive_render.exe',
    'bin\kioworker.exe',
    'bin\kbuildsycoca6.exe',
    'bin\melt.exe',
    'bin\ffmpeg.exe',
    'bin\ffprobe.exe',
    'bin\ffplay.exe',
    'bin\qt.conf',
    'bin\platforms\qwindows.dll',
    'bin\Qt6Core.dll',
    'bin\Qt6Gui.dll',
    'bin\Qt6Widgets.dll',
    'bin\Qt6Network.dll',
    'bin\kf6\kio\kio_file.dll',
    'share\mlt\profiles\dv_pal',
    'syncut.ico'
)
foreach ($rel in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $rel))) { throw "$Label required runtime file missing: $rel" }
}

$mltModules = @(Get-ChildItem -LiteralPath (Join-Path $Root 'lib\mlt') -Filter 'libmlt*.dll' -File -ErrorAction SilentlyContinue)
if ($mltModules.Count -lt 5) { throw "$Label MLT module count is too small: $($mltModules.Count)" }
$frei0rPlugins = @(Get-ChildItem -LiteralPath (Join-Path $Root 'lib\frei0r-1') -Filter '*.dll' -File -ErrorAction SilentlyContinue)
if ($frei0rPlugins.Count -lt 10) { throw "$Label Frei0r plugin count is too small: $($frei0rPlugins.Count)" }
$controls = Get-ChildItem -LiteralPath (Join-Path $bin 'qml') -Filter 'qtquickcontrols2plugin.dll' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $controls) { throw "$Label QtQuick Controls plugin is missing." }

$qtConf = Get-Content -LiteralPath (Join-Path $bin 'qt.conf') -Raw
foreach ($line in @('Prefix=..','LibraryExecutables=bin','Plugins=bin','Data=bin/data')) {
    if ($qtConf -notmatch [regex]::Escape($line)) { throw "$Label qt.conf is missing: $line" }
}

Write-Host "$Label runtime inventory passed: $($mltModules.Count) MLT modules, $($frei0rPlugins.Count) Frei0r plugins."
