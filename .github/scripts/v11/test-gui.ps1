param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Label,
    [int]$Seconds = 55
)

$ErrorActionPreference = 'Stop'

$bin = Join-Path $Root 'bin'
$exe = Join-Path $bin 'syncut.exe'

if (-not (Test-Path -LiteralPath $exe)) {
    throw "$Label Syncut executable missing: $exe"
}

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class SyncutWindowInspectorV11
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    public static string[] TitlesForProcess(int pid)
    {
        var titles = new List<string>();

        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            uint windowPid;
            GetWindowThreadProcessId(hWnd, out windowPid);

            if (windowPid == (uint)pid && IsWindowVisible(hWnd))
            {
                int length = GetWindowTextLength(hWnd);
                var builder = new StringBuilder(Math.Max(length + 1, 512));
                GetWindowText(hWnd, builder, builder.Capacity);

                string title = builder.ToString().Trim();
                if (!String.IsNullOrEmpty(title))
                {
                    titles.Add(title);
                }
            }

            return true;
        }, IntPtr.Zero);

        return titles.ToArray();
    }
}
"@

$profile = Join-Path $env:RUNNER_TEMP ("syncut-v11-clean-" + $Label)

if (Test-Path -LiteralPath $profile) {
    Remove-Item -LiteralPath $profile -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $profile | Out-Null

$old = @{
    PATH              = $env:PATH
    XDG_CONFIG_HOME   = $env:XDG_CONFIG_HOME
    XDG_CACHE_HOME    = $env:XDG_CACHE_HOME
    XDG_DATA_HOME     = $env:XDG_DATA_HOME
    MLT_PREFIX        = $env:MLT_PREFIX
    MLT_REPOSITORY    = $env:MLT_REPOSITORY
    MLT_DATA          = $env:MLT_DATA
    MLT_PROFILES_PATH = $env:MLT_PROFILES_PATH
    FREI0R_PATH       = $env:FREI0R_PATH
}

$env:XDG_CONFIG_HOME = Join-Path $profile 'config'
$env:XDG_CACHE_HOME = Join-Path $profile 'cache'
$env:XDG_DATA_HOME = Join-Path $profile 'data'
$env:PATH = "$bin;$env:SystemRoot\System32;$env:SystemRoot"

$env:MLT_PREFIX = $Root
$env:MLT_REPOSITORY = Join-Path $Root 'lib\mlt'
$env:MLT_DATA = Join-Path $Root 'share\mlt'
$env:MLT_PROFILES_PATH = Join-Path $env:MLT_DATA 'profiles'
$env:FREI0R_PATH = Join-Path $Root 'lib\frei0r-1'

$stdout = Join-Path $env:GITHUB_WORKSPACE ("syncut-$Label-out.log")
$stderr = Join-Path $env:GITHUB_WORKSPACE ("syncut-$Label-err.log")
$windowsLog = Join-Path $env:GITHUB_WORKSPACE ("syncut-$Label-windows.log")

Remove-Item -LiteralPath $stdout,$stderr,$windowsLog -Force -ErrorAction SilentlyContinue

$configName = "syncut-ci-$Label.rc"

$process = Start-Process `
    -FilePath $exe `
    -ArgumentList @('--no-welcome','--config',$configName) `
    -WorkingDirectory $bin `
    -PassThru `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr

$deadline = (Get-Date).AddSeconds($Seconds)
$seenWindow = $false
$seenTitles = New-Object System.Collections.Generic.List[string]

# ASCII only on purpose for Windows PowerShell 5.1 compatibility.
$badWindowPattern = '(?i)Welcome to Kdenlive|Kdenlive Quick Setup|Syncut setup|\berror\b|\bfatal\b|\bcrash\b|\bcritical\b'
$fatalLogPattern = '(?i)Unknown protocol.*file|Unable to create KIO worker|Could not load the Qt platform plugin|failed to load.*qml|This application failed to start|Missing package.*Frei0r|no plugins found.*mlt|Failed to open properties file.*profiles|invalid filter.*frei0r|cannot find \.rc file \"syncutui\.rc\"|Syncut XMLGUI did not create'

try {
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $process.Refresh()

        if ($process.HasExited) {
            try { $process.WaitForExit() } catch {}
            $exitCode = 'unknown'
            try {
                $process.Refresh()
                $exitCode = [string]$process.ExitCode
            } catch {}

            Write-Host "===== Syncut STDOUT ====="
            if (Test-Path -LiteralPath $stdout) {
                Get-Content -LiteralPath $stdout -Tail 400
            }

            Write-Host "===== Syncut STDERR ====="
            if (Test-Path -LiteralPath $stderr) {
                Get-Content -LiteralPath $stderr -Tail 1200
            }

            throw "$Label Syncut exited unexpectedly with code $exitCode."
        }

        $titles = [SyncutWindowInspectorV11]::TitlesForProcess($process.Id)

        if ($titles.Count -gt 0) {
            $seenWindow = $true

            foreach ($title in $titles) {
                if (-not $seenTitles.Contains($title)) {
                    $seenTitles.Add($title)
                }
            }

            $joined = $titles -join ' | '
            $line = ((Get-Date).ToString('o')) + ' | ' + $joined

            Add-Content -LiteralPath $windowsLog -Value $line
            Write-Host $joined

            if ($joined -match $badWindowPattern) {
                throw "$Label displayed an invalid setup/error window: $joined"
            }
        }

        $stderrText = Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue

        if ($stderrText -match $fatalLogPattern) {
            throw "$Label logged an incomplete or fatal runtime error."
        }
    }

    if (-not $seenWindow) {
        throw "$Label Syncut did not create a visible editor window."
    }

    if (($seenTitles -join "`n") -match '(?i)Kdenlive') {
        throw "$Label still exposed Kdenlive window branding."
    }

    Write-Host "$Label Syncut stayed alive for $Seconds seconds with no welcome/setup wizard and no runtime error."
}
finally {
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }

    Stop-Process `
        -Name 'kioworker','kbuildsycoca6','melt','ffmpeg','ffprobe','ffplay','kdenlive_render' `
        -Force `
        -ErrorAction SilentlyContinue

    foreach ($key in $old.Keys) {
        if ($null -eq $old[$key]) {
            Remove-Item -Path ("Env:" + $key) -ErrorAction SilentlyContinue
        }
        else {
            Set-Item -Path ("Env:" + $key) -Value $old[$key]
        }
    }
}
