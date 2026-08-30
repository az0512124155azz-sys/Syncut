param(
    [Parameter(Mandatory = $true)][string]$SourceRoot
)

$ErrorActionPreference = 'Stop'

function Replace-Required {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Old,
        [Parameter(Mandatory = $true)][string]$New
    )

    $text = Get-Content -LiteralPath $Path -Raw
    if ($text.Contains($New)) {
        Write-Host "Already patched: $Path"
        return
    }
    if (-not $text.Contains($Old)) {
        throw "Expected text was not found in $Path"
    }
    $text = $text.Replace($Old, $New)
    Set-Content -LiteralPath $Path -Value $text -Encoding UTF8
    Write-Host "Patched: $Path"
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

Replace-Required -Path $uiQrc -Old @'
    <qresource prefix="/kxmlgui5/kdenlive">
        <file>kdenliveui.rc</file>
    </qresource>
'@ -New @'
    <qresource prefix="/kxmlgui5/kdenlive">
        <file>kdenliveui.rc</file>
    </qresource>
    <qresource prefix="/kxmlgui5/syncut">
        <file alias="syncutui.rc">kdenliveui.rc</file>
    </qresource>
'@

Replace-Required -Path $mainWindow -Old @'
    // Since not all widgets are added yet, don't use the Save flag now
    setupGUI(KXmlGuiWindow::ToolBar | KXmlGuiWindow::StatusBar | KXmlGuiWindow::Create);
'@ -New @'
    // Since not all widgets are added yet, don't use the Save flag now.
    // Syncut has its own component id, so explicitly select its embedded XMLGUI file.
    setXMLFile(QStringLiteral("syncutui.rc"));
    setupGUI(KXmlGuiWindow::ToolBar | KXmlGuiWindow::StatusBar | KXmlGuiWindow::Create);
'@

Replace-Required -Path $mainWindow -Old @'
    QAction *officialCut = actionCollection()->action(KStandardAction::name(KStandardAction::Cut));
    QList<QKeySequence> cutShortcuts = officialCut->shortcuts();
    if (cutShortcuts.size() > 1) {
        if (cutShortcuts.at(1) == QKeySequence(Qt::SHIFT | Qt::Key_Delete)) {
            cutShortcuts.takeLast();
            officialCut->setShortcuts(cutShortcuts);
        }
    }
'@ -New @'
    QAction *officialCut = actionCollection()->action(KStandardAction::name(KStandardAction::Cut));
    if (officialCut) {
        QList<QKeySequence> cutShortcuts = officialCut->shortcuts();
        if (cutShortcuts.size() > 1) {
            if (cutShortcuts.at(1) == QKeySequence(Qt::SHIFT | Qt::Key_Delete)) {
                cutShortcuts.takeLast();
                officialCut->setShortcuts(cutShortcuts);
            }
        }
    } else {
        qWarning() << "Syncut XMLGUI did not create the standard Cut action";
    }
'@

Replace-Required -Path $mainWindow -Old @'
    timelineRender->setToolButtonStyle(toolBar()->toolButtonStyle());
'@ -New @'
    if (toolBar()) {
        timelineRender->setToolButtonStyle(toolBar()->toolButtonStyle());
    } else {
        qWarning() << "Syncut XMLGUI did not create the main toolbar";
    }
'@

foreach ($path in @($mainCpp,$coreCpp)) {
    $text = Get-Content -LiteralPath $path -Raw
    $text = $text.Replace('kxmlgui5/kdenlive/kdenliveui.rc','kxmlgui5/syncut/syncutui.rc')
    $text = $text.Replace(':/kxmlgui5/kdenlive/kdenliveui.rc',':/kxmlgui5/syncut/syncutui.rc')
    Set-Content -LiteralPath $path -Value $text -Encoding UTF8
    Write-Host "Updated Syncut XMLGUI paths: $path"
}

$text = Get-Content -LiteralPath $mainCpp -Raw
$text = $text.Replace('if (config->name().contains(QLatin1String("kdenlive"))) {','if (config->name().contains(QLatin1String("syncut")) || config->name().contains(QLatin1String("kdenlive"))) {')
Set-Content -LiteralPath $mainCpp -Value $text -Encoding UTF8

Write-Host 'Syncut startup source patch completed.'
