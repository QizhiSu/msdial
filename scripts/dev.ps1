#Requires -Version 5.1
<#
.SYNOPSIS
    MS-DIAL 开发环境包装脚本（适配用户级 .NET 8 SDK）
.DESCRIPTION
    - 不需要管理员权限
    - 自动配置 DOTNET_ROOT 与 PATH（如果未设置）
    - 提供 build / restore / run / clean 子命令
.EXAMPLE
    .\scripts\dev.ps1 build           # 构建 MsdialGuiApp (Debug vendor unsupported, net48)
    .\scripts\dev.ps1 restore         # 仅 restore
    .\scripts\dev.ps1 rebuild         # clean 后 build
    .\scripts\dev.ps1 build -Configuration Release -Framework net472
    .\scripts\dev.ps1 test            # 跑 tests
#>

[CmdletBinding()]
param(
    [ValidateSet('build','restore','rebuild','test','clean','run')]
    [string]$Command = 'build',

    [ValidateSet('Debug','Release','Debug vendor unsupported','Release vendor unsupported')]
    [string]$Configuration = 'Debug vendor unsupported',

    [ValidateSet('net472','net48','net481','net8.0','netstandard2.0','netstandard2.1')]
    [string]$Framework = 'net48',

    [switch]$WithLibraries
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
        & $DotnetExe build $MainProject `
            /p:Configuration="$Configuration" `
            /p:DownloadLibraries=$(if ($WithLibraries) {'true'} else {'false'}) `
            --framework $Framework
    }
    'restore' {
        Write-Host "==> Restoring packages" -ForegroundColor Cyan
        & $DotnetExe restore $MainProject /p:Configuration="$Configuration" /p:DownloadLibraries=false
    }
    'rebuild' {
        Write-Host "==> Clean + Build" -ForegroundColor Cyan
        & $DotnetExe build $MainProject /p:Configuration="$Configuration" /t:Rebuild `
            /p:DownloadLibraries=$(if ($WithLibraries) {'true'} else {'false'}) `
            --framework $Framework
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
}

if ($LASTEXITCODE -ne 0) {
    throw "dotnet exited with code $LASTEXITCODE"
}
Write-Host "==> Done." -ForegroundColor Green