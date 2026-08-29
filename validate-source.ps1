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

if (-not (Test-Path -LiteralPath $Archive)) {
    throw "Source archive does not exist: $Archive"
}

$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Archive))
try {
    if ($zip.Entries.Count -lt 1000) {
        throw "Source archive has too few entries: $($zip.Entries.Count)"
    }
    $requiredEntries = @(
        'Syncut-Claude-Handoff/CMakeLists.txt',
        'Syncut-Claude-Handoff/src/main.cpp',
        'Syncut-Claude-Handoff/src/mltconnection.cpp',
        'Syncut-Claude-Handoff/src/syncut/aiassistantwidget.cpp',
        'Syncut-Claude-Handoff/src/syncut/aiassistantwidget.h',
        'Syncut-Claude-Handoff/src/icons.qrc',
        'Syncut-Claude-Handoff/src/dialogs/Splash.qml',
        'Syncut-Claude-Handoff/data/pics/syncut-logo.png',
        'Syncut-Claude-Handoff/data/icons/48-apps-syncut.png'
    )
    foreach ($entry in $requiredEntries) {
        if (-not ($zip.Entries.FullName -contains $entry)) {
            throw "Required source entry missing: $entry"
        }
    }
} finally {
    $zip.Dispose()
}

if (Test-Path -LiteralPath $Destination) {
    Remove-Item -LiteralPath $Destination -Recurse -Force
}
Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force

$src = Join-Path $Destination 'Syncut-Claude-Handoff'
if (-not (Test-Path -LiteralPath (Join-Path $src 'CMakeLists.txt'))) {
    throw 'Source extraction failed.'
}

# Known MinGW include-path correction.
$meltBuilder = Join-Path $src 'src\timeline2\model\builders\meltBuilder.cpp'
if (Test-Path -LiteralPath $meltBuilder) {
    $text = [System.IO.File]::ReadAllText($meltBuilder)
    $fixed = $text.Replace('#include "../undohelper.hpp"', '#include "undohelper.hpp"')
    if ($fixed -ne $text) {
        Write-Utf8NoBom -Path $meltBuilder -Text $fixed
        Write-Host 'Patched meltBuilder.cpp include path.'
    }
}

# Preserve 16-byte D3D constant-buffer alignment with explicit precedence.
$d3d = Join-Path $src 'src\monitor\d3dvideowidget.cpp'
if (Test-Path -LiteralPath $d3d) {
    $text = [System.IO.File]::ReadAllText($d3d)
    $fixed = $text.Replace('sizeof(m_constants) + 0xf & 0xfffffff0', '(sizeof(m_constants) + 0xf) & 0xfffffff0')
    if ($fixed -ne $text) {
        Write-Utf8NoBom -Path $d3d -Text $fixed
        Write-Host 'Patched D3D alignment expression.'
    }
}

# Syncut branding must be compiled into the actual executable, not only into
# the installer shortcut. The embedded app icon is what Windows uses for the
# taskbar and shortcut when the shortcut points at syncut.exe.
$iconsQrc = Join-Path $src 'src\icons.qrc'
$iconsText = [System.IO.File]::ReadAllText($iconsQrc)
$iconsText = $iconsText.Replace('../data/icons/48-apps-kdenlive.png', '../data/icons/48-apps-syncut.png')
$iconsText = $iconsText.Replace('../data/pics/kdenlive-logo.png', '../data/pics/syncut-logo.png')
Write-Utf8NoBom -Path $iconsQrc -Text $iconsText

$srcCmake = Join-Path $src 'src\CMakeLists.txt'
$cmakeText = [System.IO.File]::ReadAllText($srcCmake)
$cmakeText = [regex]::Replace($cmakeText, '(?m)^\s*\$\{ICONS_FOLDER\}/sc-apps-kdenlive\.svg\r?\n', '')
$cmakeText = $cmakeText.Replace('-apps-kdenlive.png', '-apps-syncut.png')
Write-Utf8NoBom -Path $srcCmake -Text $cmakeText

# Do not show the stock Kdenlive first-run Quick Setup in Syncut. The editor
# opens directly with the packaged defaults. This also removes the stock
# Kdenlive version/branding page seen on first launch.
$main = Join-Path $src 'src\main.cpp'
$mainText = [System.IO.File]::ReadAllText($main)
$oldBuild = 'if (!Core::build(packageType, false, parser.isSet(debugOption), app.url.isEmpty() && clipsToLoad.isEmpty() && !parser.isSet(disableWelcome))) {'
$newBuild = 'if (!Core::build(packageType, false, parser.isSet(debugOption), false)) {'
if (-not $mainText.Contains($oldBuild) -and -not $mainText.Contains($newBuild)) {
    throw 'Could not locate the first-run welcome condition in src/main.cpp.'
}
$mainText = $mainText.Replace($oldBuild, $newBuild)
$mainText = $mainText.Replace('aboutData.setDesktopFileName(QStringLiteral("org.kde.kdenlive"));', 'aboutData.setDesktopFileName(QStringLiteral("syncut"));')
Write-Utf8NoBom -Path $main -Text $mainText

# Keep the normal splash, but remove visible Kdenlive branding from it.
$splash = Join-Path $src 'src\dialogs\Splash.qml'
$splashText = [System.IO.File]::ReadAllText($splash)
$splashText = $splashText.Replace('KI18n.i18n("Kdenlive")', 'KI18n.i18n("Syncut")')
$splashText = $splashText.Replace('Welcome to Kdenlive Quick Setup', 'Welcome to Syncut')
$splashText = $splashText.Replace('Kdenlive crashed on last start.', 'Syncut crashed on last start.')
$splashText = $splashText.Replace('Kdenlive was upgraded.', 'Syncut was upgraded.')
$splashText = $splashText.Replace('Help us make Kdenlive even better', 'Help us make Syncut even better')
Write-Utf8NoBom -Path $splash -Text $splashText

$simpleSplash = Join-Path $src 'src\dialogs\Simplesplash.qml'
if (Test-Path -LiteralPath $simpleSplash) {
    $simpleText = [System.IO.File]::ReadAllText($simpleSplash)
    $simpleText = $simpleText.Replace('KI18n.i18n("Kdenlive")', 'KI18n.i18n("Syncut")')
    Write-Utf8NoBom -Path $simpleSplash -Text $simpleText
}

# Verify branding patches before compiling.
$verifyMain = [System.IO.File]::ReadAllText($main)
if ($verifyMain -notmatch 'Core::build\(packageType, false, parser\.isSet\(debugOption\), false\)') {
    throw 'Syncut no-welcome patch was not applied.'
}
if ($verifyMain -match 'aboutData\.setDesktopFileName\(QStringLiteral\("org\.kde\.kdenlive"\)\)') {
    throw 'Old Kdenlive desktop file name is still compiled into Syncut.'
}
$verifyQrc = [System.IO.File]::ReadAllText($iconsQrc)
if ($verifyQrc -notmatch '48-apps-syncut\.png' -or $verifyQrc -notmatch 'syncut-logo\.png') {
    throw 'Syncut embedded icon/logo resources were not applied.'
}
$verifyCmake = [System.IO.File]::ReadAllText($srcCmake)
if ($verifyCmake -match 'apps-kdenlive\.png') {
    throw 'Windows executable icon list still contains Kdenlive PNG icons.'
}

$ai = Join-Path $src 'src\syncut'
$required = @(
    (Join-Path $ai 'aiassistantwidget.cpp'),
    (Join-Path $ai 'aiassistantwidget.h'),
    (Join-Path $src 'data\icons\22-apps-syncut.png'),
    (Join-Path $src 'data\icons\128-apps-syncut.png')
)
foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath $file)) {
        throw "Required file missing: $file"
    }
}

$aiFiles = Get-ChildItem -LiteralPath $ai -File -Recurse
$allAi = ($aiFiles | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
if ($allAi -match '\bemit\b') {
    throw 'Raw Qt emit keyword found. QT_NO_KEYWORDS requires Q_EMIT.'
}
if ($allAi -match 'generativelanguage|api\.openai|api\.nvidia|api\.anthropic|Gemini') {
    throw 'Cloud AI/API code found in local-only Syncut AI.'
}
if ($allAi -match 'https?://(?!127\.0\.0\.1|localhost)') {
    throw 'Non-local HTTP endpoint found in Syncut AI.'
}

$cpp = [System.IO.File]::ReadAllText((Join-Path $ai 'aiassistantwidget.cpp'))
if ($cpp -match 'QJsonObject\s*\{\{[^\r\n]*\+') {
    throw 'Risky QStringBuilder expression inside QJsonObject initializer found.'
}
if ($cpp -notmatch '127\.0\.0\.1:11434') {
    throw 'Ollama localhost detection is missing.'
}
if ($cpp -notmatch '127\.0\.0\.1:1234') {
    throw 'Bionic/LM Studio localhost detection is missing.'
}

$sourceFiles = Get-ChildItem -LiteralPath (Join-Path $src 'src') -File -Recurse -Include *.cpp,*.cc,*.cxx,*.h,*.hpp,*.qml
foreach ($file in $sourceFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    if ($content -match '(?m)^(<<<<<<<|=======|>>>>>>>)') {
        throw "Unresolved merge-conflict marker found in $($file.FullName)"
    }
}

Write-Host 'Source, Syncut branding, icon, no-welcome, and local-AI checks passed.'
