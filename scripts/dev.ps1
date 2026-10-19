#Requires -Version 5.1
<#
.SYNOPSIS
    MS-DIAL 开发环境包装脚本（适配用户级 .NET 8 SDK）
.DESCRIPTION
    - 不需要管理员权限
    - 自动配置 DOTNET_ROOT 与 PATH（如果未设置）
    - 提供 build / restore / run / clean / watch 子命令
.EXAMPLE
    .\scripts\dev.ps1 build           # 构建 MsdialGuiApp (Debug vendor unsupported, net48)
    .\scripts\dev.ps1 restore         # 仅 restore
    .\scripts\dev.ps1 rebuild         # clean 后 build
    .\scripts\dev.ps1 build -Configuration Release -Framework net472
    .\scripts\dev.ps1 test            # 跑 tests
    .\scripts\dev.ps1 watch           # 文件变化时自动 build + 启动 GUI
    .\scripts\dev.ps1 watch -NoLaunch # 文件变化时只 build（不启动 GUI）
.NOTES
    - `watch` 用 dotnet watch 监视 .cs / .xaml / .csproj 变化
    - 每次变化会 **重启 GUI**（不支持 in-process 热重载,这是 .NET Framework WPF 的固有限制)
    - 已打开的数据文件每次重启都会丢失,需要手动重新打开
#>

[CmdletBinding()]
param(
    [ValidateSet('build','restore','rebuild','test','clean','run','watch')]
    [string]$Command = 'build',

    [ValidateSet('Debug','Release','Debug vendor unsupported','Release vendor unsupported')]
    [string]$Configuration = 'Debug vendor unsupported',

    [ValidateSet('net472','net48','net481','net8.0','netstandard2.0','netstandard2.1')]
    [string]$Framework = 'net48',

    [switch]$WithLibraries,

    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path "$PSScriptRoot\.."
$DotnetRoot = "$env:USERPROFILE\.dotnet"
$DotnetExe = Join-Path $DotnetRoot 'dotnet.exe'

# 1. 确保 .NET 8 SDK 在 PATH 里（本会话）
if (-not (Test-Path $DotnetExe)) {
    throw ".NET SDK not found at $DotnetExe. Run install first (see README)."
}
if ($env:PATH -notlike "*$DotnetRoot*") {
    $env:PATH = "$DotnetRoot;$env:PATH"
    $env:DOTNET_ROOT = $DotnetRoot
}

# 2. 切换到仓库根
Set-Location $RepoRoot

# 3. 主项目
$MainProject = Join-Path $RepoRoot 'src/MSDIAL5/MsdialGuiApp/MsdialGuiApp.csproj'

# 4. 子命令
switch ($Command) {
    'build' {
        Write-Host "==> Building $MainProject" -ForegroundColor Cyan
        Write-Host "    Configuration = $Configuration" -ForegroundColor DarkCyan
        Write-Host "    Framework     = $Framework" -ForegroundColor DarkCyan
        # Use single MSBuild worker and disable shared Roslyn compilation so that
        # this script plays nicely with an already-open Visual Studio instance
        # (otherwise WPF's XAML compile pass can run out of virtual address space).
        & $DotnetExe build $MainProject `
            /p:Configuration="$Configuration" `
            /p:DownloadLibraries=$(if ($WithLibraries) {'true'} else {'false'}) `
            --framework $Framework `
            -m:1 `
            /p:UseSharedCompilation=false
    }
    'restore' {
        Write-Host "==> Restoring packages" -ForegroundColor Cyan
        & $DotnetExe restore $MainProject /p:Configuration="$Configuration" /p:DownloadLibraries=false
    }
    'rebuild' {
        Write-Host "==> Clean + Build" -ForegroundColor Cyan
        & $DotnetExe build $MainProject /p:Configuration="$Configuration" /t:Rebuild `
            /p:DownloadLibraries=$(if ($WithLibraries) {'true'} else {'false'}) `
            --framework $Framework `
            -m:1 `
            /p:UseSharedCompilation=false
    }
    'clean' {
        Write-Host "==> Clean" -ForegroundColor Cyan
        & $DotnetExe clean $MainProject /p:Configuration="$Configuration"
    }
    'test' {
        Write-Host "==> Running tests" -ForegroundColor Cyan
        & $DotnetExe test (Join-Path $RepoRoot 'tests/MSDIAL5/MsdialCoreTestApp/MsdialCoreTestApp.csproj') `
            /p:Configuration="$Configuration"
    }
    'run' {
        Write-Host "==> Launching MSDIAL.exe" -ForegroundColor Cyan
        $exe = Join-Path $RepoRoot "src/MSDIAL5/MsdialGuiApp/bin/$Configuration/$Framework/MSDIAL.exe"
        if (-not (Test-Path $exe)) {
            throw "Built EXE not found: $exe. Run 'build' first."
        }
        & $exe
    }
    'watch' {
        $exe = Join-Path $RepoRoot "src/MSDIAL5/MsdialGuiApp/bin/$Configuration/$Framework/MSDIAL.exe"
        $withLibs = if ($WithLibraries) {'true'} else {'false'}
        $buildArgs = @(
            'build', $MainProject
            "/p:Configuration=$Configuration"
            "/p:DownloadLibraries=$withLibs"
            "--framework", $Framework
            "-m:1"
            "/p:UseSharedCompilation=false"
        )

        # 1) Initial build so the EXE exists
        Write-Host "==> Initial build of $MainProject" -ForegroundColor Cyan
        & $DotnetExe @buildArgs
        if ($LASTEXITCODE -ne 0) { throw "Initial build failed." }
        if (-not (Test-Path $exe)) { throw "Build did not produce $exe" }

        # 2) Set up the file watcher
        # We watch the entire repo but ignore bin/obj/.nuget to avoid loops.
        $ignore = @('\bin\', '\obj\', '\.nuget\', '\.git\', 'packages\')
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $RepoRoot
        $watcher.IncludeSubdirectories = $true
        $watcher.Filter = '*.*'
        $watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor `
                                [System.IO.NotifyFilters]::LastWrite -bor `
                                [System.IO.NotifyFilters]::DirectoryName
        $watcher.EnableRaisingEvents = $true
        Write-Host "==> Watching $RepoRoot for .cs/.xaml/.csproj changes" -ForegroundColor Cyan
        Write-Host "    (debounce 800ms; ignores bin/obj/.nuget/.git)" -ForegroundColor DarkCyan

        # 3) Debounce: many editors fire several events per save
        $buildTimer = New-Object System.Timers.Timer
        $buildTimer.Interval = 800
        $buildTimer.AutoReset = $false
        $buildPending = $false
        $buildTimer.Add_Elapsed({ $script:buildPending = $true })

        $onChange = {
            $path = $EventArgs.FullPath
            foreach ($ig in $ignore) { if ($path -like "*$ig*") { return } }
            Write-Host ("    [change] {0}" -f (Resolve-Path -Path $path -Relative)) -ForegroundColor DarkGray
            $script:buildTimer.Stop()
            $script:buildTimer.Start()
        }
        Register-ObjectEvent -InputObject $watcher -EventName 'Changed'  -Action $onChange | Out-Null
        Register-ObjectEvent -InputObject $watcher -EventName 'Created'  -Action $onChange | Out-Null
        Register-ObjectEvent -InputObject $watcher -EventName 'Renamed'  -Action $onChange | Out-Null
        Register-ObjectEvent -InputObject $watcher -EventName 'Deleted'  -Action $onChange | Out-Null

        # 4) Launch the GUI in the background (does not block)
        function Start-Gui {
            Get-Process MSDIAL -ErrorAction SilentlyContinue | Stop-Process -Force
            Start-Sleep -Milliseconds 200
            $p = Start-Process -FilePath $exe -PassThru
            Write-Host ("==> GUI running (PID {0}). Open your data here. Save a file to trigger a rebuild + restart." -f $p.Id) -ForegroundColor Green
        }
        function Invoke-Build {
            Write-Host '==> Building...' -ForegroundColor Cyan
            $output = & $DotnetExe @buildArgs 2>&1
            $code = $LASTEXITCODE
            if ($code -ne 0) {
                Write-Host "Build FAILED (exit $code)" -ForegroundColor Red
                $output | Select-String -Pattern 'error [A-Z]+[0-9]+:' | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
                return $false
            }
            Write-Host 'Build succeeded.' -ForegroundColor Green
            return $true
        }

        if (-not $NoLaunch) { Start-Gui }

        Write-Host "==> watch loop running. Press Ctrl+C in this window to stop." -ForegroundColor Cyan

        # 5) Main loop
        while ($true) {
            Start-Sleep -Milliseconds 200
            if (-not $buildPending) { continue }
            $buildPending = $false
            if (Invoke-Build) {
                if (-not $NoLaunch) { Start-Gui }
            }
        }
    }
}

if ($LASTEXITCODE -ne 0) {
    throw "dotnet exited with code $LASTEXITCODE"
}
Write-Host "==> Done." -ForegroundColor Green