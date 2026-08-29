param(
    [string]$Archive = 'syncut-source.zip',
    [string]$Destination = 'source'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

if (-not (Test-Path -LiteralPath $Archive)) { throw "Source archive does not exist: $Archive" }
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Archive))
try {
    if ($zip.Entries.Count -lt 1000) { throw "Source archive has too few entries: $($zip.Entries.Count)" }
    foreach ($entry in @(
        'Syncut-Claude-Handoff/CMakeLists.txt',
        'Syncut-Claude-Handoff/src/main.cpp',
        'Syncut-Claude-Handoff/src/mainwindow.cpp',
        'Syncut-Claude-Handoff/src/dialogs/wizard.cpp',
        'Syncut-Claude-Handoff/src/icons.qrc',
        'Syncut-Claude-Handoff/src/syncut/aiassistantwidget.cpp',
        'Syncut-Claude-Handoff/data/icons/syncut.ico'
    )) {
        if (-not ($zip.Entries.FullName -contains $entry)) { throw "Required source entry missing: $entry" }
    }
} finally {
    $zip.Dispose()
}

if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force
$src = Join-Path $Destination 'Syncut-Claude-Handoff'
if (-not (Test-Path -LiteralPath (Join-Path $src 'CMakeLists.txt'))) { throw 'Source extraction failed.' }

# Two deterministic MinGW fixes retained from the previously proven build path.
$meltBuilder = Join-Path $src 'src\timeline2\model\builders\meltBuilder.cpp'
if (Test-Path -LiteralPath $meltBuilder) {
    $text = [System.IO.File]::ReadAllText($meltBuilder)
    $fixed = $text.Replace('#include "../undohelper.hpp"', '#include "undohelper.hpp"')
    if ($fixed -ne $text) { Write-Utf8NoBom $meltBuilder $fixed }
}
$d3d = Join-Path $src 'src\monitor\d3dvideowidget.cpp'
if (Test-Path -LiteralPath $d3d) {
    $text = [System.IO.File]::ReadAllText($d3d)
    $fixed = $text.Replace('sizeof(m_constants) + 0xf & 0xfffffff0', '(sizeof(m_constants) + 0xf) & 0xfffffff0')
    if ($fixed -ne $text) { Write-Utf8NoBom $d3d $fixed }
}

$main = [System.IO.File]::ReadAllText((Join-Path $src 'src\main.cpp'))
$mainWindow = [System.IO.File]::ReadAllText((Join-Path $src 'src\mainwindow.cpp'))
$wizard = [System.IO.File]::ReadAllText((Join-Path $src 'src\dialogs\wizard.cpp'))
$iconsQrc = [System.IO.File]::ReadAllText((Join-Path $src 'src\icons.qrc'))
$srcCmake = [System.IO.File]::ReadAllText((Join-Path $src 'src\CMakeLists.txt'))
$settings = [System.IO.File]::ReadAllText((Join-Path $src 'src\kdenlivesettings.kcfg'))

foreach ($required in @(
    'configureSyncutBundledRuntime',
    'MLT_REPOSITORY',
    'MLT_DATA',
    'MLT_PROFILES_PATH',
    'FREI0R_PATH',
    'QStringLiteral("0.3.1")',
    'Core::build(packageType, false, parser.isSet(debugOption), false)',
    ':/pics/syncut.png'
)) {
    if (-not $main.Contains($required)) { throw "Required Syncut source marker missing: $required" }
}
if ($main -match 'SYNCUTQSS|app\.setStyleSheet\(QStringLiteral\(R"SYNCUTQSS') {
    throw 'The unsafe global Syncut stylesheet is still present.'
}
if ($mainWindow -notmatch 'if \(w->isOk\(\)\)\s*\{\s*w->adjustSettings\(\)') {
    throw 'Healthy first-run setup is not configured to run silently.'
}
if ($wizard -match 'Welcome to Kdenlive') { throw 'Stock Kdenlive setup branding remains in wizard.cpp.' }
if ($iconsQrc -notmatch '48-apps-syncut\.png' -or $iconsQrc -notmatch 'syncut-logo\.png') {
    throw 'Syncut embedded icon resources are incomplete.'
}
if ($srcCmake -match 'ICON_FILES[\s\S]*apps-kdenlive') { throw 'Windows executable still uses Kdenlive app icons.' }
if ($srcCmake -notmatch '1024-apps-syncut\.png') { throw 'High-resolution Syncut app icon is missing from CMake.' }
if ($settings -notmatch 'name="showWelcome"[\s\S]{0,160}<default>false</default>') {
    throw 'Welcome screen default is not disabled.'
}

$icon = Get-Item -LiteralPath (Join-Path $src 'data\icons\syncut.ico')
if ($icon.Length -lt 20000) { throw "Syncut ICO is unexpectedly small: $($icon.Length) bytes" }

$ai = Join-Path $src 'src\syncut'
$allAi = (Get-ChildItem -LiteralPath $ai -File -Recurse | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
if ($allAi -match '\bemit\b') { throw 'Raw Qt emit keyword found; QT_NO_KEYWORDS requires Q_EMIT.' }
if ($allAi -match 'generativelanguage|api\.openai|api\.nvidia|api\.anthropic|Gemini') {
    throw 'Cloud AI/API code found in local-only Syncut AI.'
}
if ($allAi -match 'https?://(?!127\.0\.0\.1|localhost)') { throw 'Non-local AI HTTP endpoint found.' }
if ($allAi -notmatch '127\.0\.0\.1:11434') { throw 'Ollama localhost probe is missing.' }

$sourceFiles = Get-ChildItem -LiteralPath (Join-Path $src 'src') -File -Recurse -Include *.cpp,*.cc,*.cxx,*.h,*.hpp,*.qml
foreach ($file in $sourceFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    if ($content -match '(?m)^(<<<<<<<|=======|>>>>>>>)') { throw "Merge conflict marker found in $($file.FullName)" }
}

Write-Host 'Source integrity, native UI recovery, branding, bundled runtime, and local-AI checks passed.'
