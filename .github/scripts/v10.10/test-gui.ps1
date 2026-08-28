param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Label,
    [int]$Seconds = 75
)

$ErrorActionPreference = 'Stop'
$bin = Join-Path $Root 'bin'
$exe = Join-Path $bin 'syncut.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    throw "Syncut executable is missing: $exe"
}

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class SyncutWindowInspector {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    public static string[] TitlesForProcess(int pid) {
        var titles = new List<string>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            uint windowPid;
            GetWindowThreadProcessId(hWnd, out windowPid);
            if (windowPid == (uint)pid && IsWindowVisible(hWnd)) {
                int length = GetWindowTextLength(hWnd);
                var builder = new StringBuilder(Math.Max(length + 1, 512));
                GetWindowText(hWnd, builder, builder.Capacity);
                string title = builder.ToString().Trim();
                if (!String.IsNullOrEmpty(title)) titles.Add(title);
            }
            return true;
        }, IntPtr.Zero);
        return titles.ToArray();
    }
}
"@

$profile = Join-Path $env:RUNNER_TEMP ("syncut-clean-" + $Label)
if (Test-Path -LiteralPath $profile) {
    Remove-Item -LiteralPath $profile -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $profile | Out-Null

$env:XDG_CONFIG_HOME = Join-Path $profile 'config'
$env:XDG_CACHE_HOME = Join-Path $profile 'cache'
$env:XDG_DATA_HOME = Join-Path $profile 'data'
$env:MLT_PREFIX = $Root
$env:MLT_REPOSITORY = Join-Path $Root 'lib\mlt-7'
$env:MLT_DATA = Join-Path $Root 'share\mlt-7'
$env:PATH = "$bin;$env:SystemRoot\System32;$env:SystemRoot"

$stdout = Join-Path $env:GITHUB_WORKSPACE ("syncut-$Label-out.log")
$stderr = Join-Path $env:GITHUB_WORKSPACE ("syncut-$Label-err.log")
$windowsLog = Join-Path $env:GITHUB_WORKSPACE ("syncut-$Label-windows.log")
Remove-Item -LiteralPath $stdout,$stderr,$windowsLog -Force -ErrorAction SilentlyContinue

$process = Start-Process -FilePath $exe -WorkingDirectory $bin -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline = (Get-Date).AddSeconds($Seconds)
$seenWindow = $false
$badWindowPattern = '(?i)\berror\b|\bfatal\b|\bcrash\b|\bcritical\b'
$fatalLogPattern = '(?i)Unknown protocol\s*["'']?file|Unable to create KIO worker|Could not load the Qt platform plugin|failed to load.*qml|This application failed to start'

try {
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $process.Refresh()
        if ($process.HasExited) {
            if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Tail 400 }
            if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Tail 800 }
            throw "$Label Syncut exited unexpectedly with code $($process.ExitCode)."
        }

        $titles = [SyncutWindowInspector]::TitlesForProcess($process.Id)
        if ($titles.Count -gt 0) {
            $seenWindow = $true
            $line = ((Get-Date).ToString('o') + ' | ' + ($titles -join ' | '))
            Add-Content -LiteralPath $windowsLog -Value $line
            Write-Host $line
            if (($titles -join "`n") -match $badWindowPattern) {
                throw "$Label Syncut displayed an error window: $($titles -join ' | ')"
            }
        }

        $stderrText = Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue
        if ($stderrText -match $fatalLogPattern) {
            throw "$Label Syncut logged a fatal runtime error."
        }
    }

    if (-not $seenWindow) {
        throw "$Label Syncut did not create a visible window."
    }
    Write-Host "$Label Syncut stayed alive for $Seconds seconds without an error window."
} finally {
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
    Stop-Process -Name 'kioworker','kbuildsycoca6','melt','ffmpeg','ffprobe','kdenlive_render' -Force -ErrorAction SilentlyContinue
}
