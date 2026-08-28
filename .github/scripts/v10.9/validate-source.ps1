param(
    [string]$Archive = 'syncut-source.zip',
    [string]$Destination = 'source'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

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
        'Syncut-Claude-Handoff/src/syncut/aiassistantwidget.h'
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
    $text = Get-Content -LiteralPath $meltBuilder -Raw
    $fixed = $text.Replace('#include "../undohelper.hpp"', '#include "undohelper.hpp"')
    if ($fixed -ne $text) {
        Set-Content -LiteralPath $meltBuilder -Value $fixed -Encoding UTF8
        Write-Host 'Patched meltBuilder.cpp include path.'
    }
}

# Preserve the intended 16-byte D3D constant-buffer alignment while making
# operator precedence explicit for current GCC versions.
$d3d = Join-Path $src 'src\monitor\d3dvideowidget.cpp'
if (Test-Path -LiteralPath $d3d) {
    $text = Get-Content -LiteralPath $d3d -Raw
    $fixed = $text.Replace('sizeof(m_constants) + 0xf & 0xfffffff0', '(sizeof(m_constants) + 0xf) & 0xfffffff0')
    if ($fixed -ne $text) {
        Set-Content -LiteralPath $d3d -Value $fixed -Encoding UTF8
        Write-Host 'Patched D3D alignment expression.'
    }
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
$allAi = ($aiFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
if ($allAi -match '\bemit\b') {
    throw 'Raw Qt emit keyword found. QT_NO_KEYWORDS requires Q_EMIT.'
}
if ($allAi -match 'generativelanguage|api\.openai|api\.nvidia|api\.anthropic|Gemini') {
    throw 'Cloud AI/API code found in local-only Syncut AI.'
}
if ($allAi -match 'https?://(?!127\.0\.0\.1|localhost)') {
    throw 'Non-local HTTP endpoint found in Syncut AI.'
}

$cpp = Get-Content -LiteralPath (Join-Path $ai 'aiassistantwidget.cpp') -Raw
if ($cpp -match 'QJsonObject\s*\{\{[^\r\n]*\+') {
    throw 'Risky QStringBuilder expression inside QJsonObject initializer found.'
}
if ($cpp -notmatch '127\.0\.0\.1:11434') {
    throw 'Ollama localhost detection is missing.'
}
if ($cpp -notmatch '127\.0\.0\.1:1234') {
    throw 'Bionic or LM Studio localhost detection is missing.'
}
if ($cpp -notmatch 'return true;') {
    throw 'Built-in local fallback availability check is missing.'
}

$sourceFiles = Get-ChildItem -LiteralPath (Join-Path $src 'src') -File -Recurse -Include *.cpp,*.cc,*.cxx,*.h,*.hpp
foreach ($file in $sourceFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content -match '(?m)^(<<<<<<<|=======|>>>>>>>)') {
        throw "Unresolved merge-conflict marker found in $($file.FullName)"
    }
}

Write-Host 'Source archive, branding, and local-AI safety checks passed.'
