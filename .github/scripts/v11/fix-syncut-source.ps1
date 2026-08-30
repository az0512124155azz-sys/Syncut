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

foreach ($required in @($uiQrc,$mainWindow,$mainCpp,$coreCpp)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required source file is missing: $required"
    }
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

$cutMarker = 'QAction *officialCut = actionCollection()->action(KStandardAction::name(KStandardAction::Cut));'
if ($mw.Contains($cutMarker) -and $mw -notmatch '(?s)QAction\s*\*officialCut.*?if\s*\(\s*officialCut\s*\)') {
    $start = $mw.IndexOf($cutMarker)
    $nextMarker = 'connect(m_projectMonitor'
    $end = $mw.IndexOf($nextMarker, $start)
    if ($end -gt $start) {
        $segment = $mw.Substring($start, $end - $start)
        if ($segment -match 'officialCut->shortcuts\(\)') {
            $guarded = @"
QAction *officialCut = actionCollection()->action(KStandardAction::name(KStandardAction::Cut));
    if (officialCut) {
        QList<QKeySequence> cutShortcuts = officialCut->shortcuts();
        if (cutShortcuts.size() > 1 && cutShortcuts.at(1) == QKeySequence(Qt::SHIFT | Qt::Key_Delete)) {
            cutShortcuts.takeLast();
            officialCut->setShortcuts(cutShortcuts);
        }
    } else {
        qWarning() << "Syncut XMLGUI did not create the standard Cut action";
    }

"@
            $mw = $mw.Substring(0,$start) + $guarded + $mw.Substring($end)
        }
    }
}
Write-Text -Path $mainWindow -Text $mw

foreach ($path in @($mainCpp,$coreCpp)) {
    $text = Read-Text $path
    $text = $text.Replace(':/kxmlgui5/kdenlive/kdenliveui.rc', ':/kxmlgui5/syncut/syncutui.rc')
    $text = $text.Replace('kxmlgui5/kdenlive/kdenliveui.rc', 'kxmlgui5/syncut/syncutui.rc')
    Write-Text -Path $path -Text $text
}

$main = Read-Text $mainCpp
$main = $main.Replace(
    'if (config->name().contains(QLatin1String("kdenlive"))) {',
    'if (config->name().contains(QLatin1String("syncut")) || config->name().contains(QLatin1String("kdenlive"))) {'
)
Write-Text -Path $mainCpp -Text $main

$qrcCheck = Read-Text $uiQrc
$mwCheck = Read-Text $mainWindow
if ($qrcCheck -notmatch '(?s)/kxmlgui5/syncut.*syncutui\.rc') {
    throw 'Postcondition failed: Syncut XMLGUI resource alias missing.'
}
if ($mwCheck -notmatch 'setXMLFile\s*\(\s*QStringLiteral\s*\(\s*"syncutui\.rc"') {
    throw 'Postcondition failed: MainWindow does not select syncutui.rc.'
}
Write-Host 'Syncut startup source patch completed successfully.'
