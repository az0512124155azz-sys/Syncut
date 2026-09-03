param(
    [Parameter(Mandatory = $true)][string]$SourceRoot
)

$ErrorActionPreference = 'Stop'

function Read-Text {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.File]::ReadAllText($Path)
}

function Write-Text {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $Text = $Text -replace "`r`n", "`n"
    $Text = $Text -replace "`r", "`n"
    $Text = $Text.TrimEnd("`n") + "`n"
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

$uiQrc = Join-Path $SourceRoot 'src\uiresources.qrc'
$mainWindow = Join-Path $SourceRoot 'src\mainwindow.cpp'
$mainCpp = Join-Path $SourceRoot 'src\main.cpp'
$coreCpp = Join-Path $SourceRoot 'src\core.cpp'

foreach ($required in @($uiQrc,$mainWindow,$mainCpp,$coreCpp,$visualSource)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required source file is missing: $required"
    }
}



# The archive handoff omitted part of Kdenlive's canonical MainWindow implementation.
$upstreamUrl = 'https://raw.githubusercontent.com/KDE/kdenlive/master/src/mainwindow.cpp'
$upstreamTemp = Join-Path $env:TEMP 'syncut-upstream-mainwindow.cpp'
Invoke-WebRequest -Uri $upstreamUrl -OutFile $upstreamTemp
if (-not (Test-Path -LiteralPath $upstreamTemp) -or (Get-Item -LiteralPath $upstreamTemp).Length -lt 200000) { throw 'Failed to retrieve the complete upstream MainWindow implementation.' }
Copy-Item -LiteralPath $upstreamTemp -Destination $mainWindow -Force
$upstreamMainWindow = Read-Text $mainWindow
$upstreamMainWindow = [regex]::Replace($upstreamMainWindow, '(?s)\s*connect\(bin, &Bin::requestBinCloseForFolder, this, \[this\]\(const QString &folderId\) \{.*?\n\s*\}\);', '')
Write-Text -Path $mainWindow -Text $upstreamMainWindow
$requiredMainWindowDefinitions = @(
    'MainWindow::~MainWindow',
    'MainWindow::slotFullScreen',
    'MainWindow::configureNotifications',
    'MainWindow::slotReloadEffects',
    'MainWindow::finishUiSetup',
    'MainWindow::slotConnectMonitors',
    'MainWindow::buildGenerator',
    'MainWindow::queryClose',
    'MainWindow::saveProperties',
    'MainWindow::saveNewToolbarConfig',
    'MainWindow::loadBins'
)
$mainWindowText = Read-Text $mainWindow
$stillMissing = @($requiredMainWindowDefinitions | Where-Object { $mainWindowText -notmatch [regex]::Escape($_) })
if ($stillMissing.Count -gt 0) {
    throw "Archive src/mainwindow.cpp is incomplete: $($stillMissing -join ', ')"
}

# Keep the archive's src/mainwindow.cpp. The repository-root copy is a
# truncated handoff artifact and replacing this file with it causes linker
# failures for the MainWindow methods above.
Write-Host 'Using archive src/mainwindow.cpp; skipped truncated repository-root copy.'



# Apply Syncut's visual language to the canonical archive main.cpp.
$visualText = Read-Text $visualSource
$styleMatch = [regex]::Match($visualText, '(?s)    // Syncut visual language:.*?SYNCUTQSS"\)\);')
if (-not $styleMatch.Success) {
    throw 'Syncut visual language block is missing from repository-root main.cpp.'
}
$styleBlock = $styleMatch.Value
$archiveMainText = Read-Text $mainCpp
if ($archiveMainText -notmatch 'Syncut visual language:') {
    $styleMarker = '    // Try to detect package type'
    if ($archiveMainText -notmatch [regex]::Escape($styleMarker)) {
        throw 'Could not find main.cpp style insertion point.'
    }
    $archiveMainText = $archiveMainText.Replace($styleMarker, $styleBlock + [Environment]::NewLine + [Environment]::NewLine + $styleMarker)
    Write-Text -Path $mainCpp -Text $archiveMainText
    Write-Host 'Applied Syncut visual language to archive src/main.cpp.'
} else {
    Write-Host 'Syncut visual language already present in archive src/main.cpp.'
}

$qrc = Read-Text $uiQrc
if ($qrc -notmatch '(?s)<qresource\s+prefix=["'']/kxmlgui5/syncut["'']>.*?syncutui\.rc.*?</qresource>') {
    $syncutBlock = @"
    <qresource prefix="/kxmlgui5/syncut">
        <file alias="syncutui.rc">kdenliveui.rc</file>
    </qresource>
"@
    if ($qrc -notmatch '(?i)</RCC>') {
        throw 'uiresources.qrc does not contain </RCC>.'
    }
    $qrc = [regex]::Replace($qrc, '(?i)</RCC>', $syncutBlock + '</RCC>', 1)
    Write-Text -Path $uiQrc -Text $qrc
    Write-Host 'Added Syncut XMLGUI resource alias.'
} else {
    Write-Host 'Syncut XMLGUI resource alias already exists.'
}

$mw = Read-Text $mainWindow
if ($mw -notmatch 'setXMLFile\s*\(\s*QStringLiteral\s*\(\s*"syncutui\.rc"') {
    $setupPattern = 'setupGUI\s*\(\s*KXmlGuiWindow::ToolBar\s*\|\s*KXmlGuiWindow::StatusBar\s*\|\s*KXmlGuiWindow::Create\s*\)\s*;'
    $m = [regex]::Match($mw, $setupPattern)
    if (-not $m.Success) { throw 'Could not find MainWindow setupGUI call.' }
    $replacement = 'setXMLFile(QStringLiteral("syncutui.rc"));' + "`n    " + $m.Value
    $mw = $mw.Substring(0,$m.Index) + $replacement + $mw.Substring($m.Index + $m.Length)
    Write-Host 'Selected syncutui.rc before setupGUI.'
}

if ($mw -match 'timelineRender->setToolButtonStyle\(toolBar\(\)->toolButtonStyle\(\)\);') {
    $toolbar = @"
if (toolBar()) {
        timelineRender->setToolButtonStyle(toolBar()->toolButtonStyle());
    } else {
        qWarning() << "Syncut XMLGUI did not create the main toolbar";
    }
"@
    $mw = $mw.Replace('timelineRender->setToolButtonStyle(toolBar()->toolButtonStyle());', $toolbar.TrimEnd())
}

Write-Text -Path $mainWindow -Text $mw
$mw = Read-Text $mainWindow
Write-Text -Path $mainWindow -Text $mw

# Keep the canonical implementation at its original CMake path so Qt automoc and the static-library link see the same MainWindow object.
$cmakeLists = Join-Path $SourceRoot 'src\CMakeLists.txt'
if (-not (Test-Path -LiteralPath $cmakeLists)) { throw "Required CMake file is missing: $cmakeLists" }
$cmakeText = Read-Text $cmakeLists
if ($cmakeText -match '(?m)^\s*mainwindow_complete\.cpp\s*$') { $cmakeText = $cmakeText -replace '(?m)^\s*mainwindow_complete\.cpp\s*$', '    mainwindow.cpp'; Write-Text -Path $cmakeLists -Text $cmakeText }
if ($cmakeText -notmatch '(?m)^\s*mainwindow\.cpp\s*$') { throw 'CMakeLists.txt must compile mainwindow.cpp.' }
Write-Host 'Canonical complete MainWindow source is enabled in kdenliveLib.'

$qrcCheck = Read-Text $uiQrc
$mwCheck = Read-Text $mainWindow
if ($qrcCheck -notmatch '(?s)/kxmlgui5/syncut.*syncutui\.rc') {
    throw 'Postcondition failed: Syncut XMLGUI resource alias missing.'
}
if ($mwCheck -notmatch 'setXMLFile\s*\(\s*QStringLiteral\s*\(\s*"syncutui\.rc"') {
    throw 'Postcondition failed: MainWindow does not select syncutui.rc.'
}
Write-Host 'Syncut startup source patch completed successfully.'
