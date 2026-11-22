# 环境引导脚本（可复现 S0）
# 用法：powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1
# 说明：只安装"用户级"组件（Flutter SDK）；VS Build Tools 需要管理员权限，脚本会给出命令。

$ErrorActionPreference = 'Stop'

$FlutterVersion = '3.47.9'
$InstallRoot    = 'C:\sofeware\software'
$FlutterHome    = Join-Path $InstallRoot 'flutter'
$DownloadDir    = Join-Path $InstallRoot '_dsh_downloads'
$Proxy          = 'http://127.0.0.1:7897'   # 本机 Clash；直连 github 不通时使用

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

Write-Step "检查 Flutter SDK"
if (Test-Path (Join-Path $FlutterHome 'bin\flutter.bat')) {
    Write-Host "已存在：$FlutterHome"
} else {
    New-Item -ItemType Directory -Path $InstallRoot, $DownloadDir -Force | Out-Null
    $zip = Join-Path $DownloadDir "flutter_windows_$FlutterVersion-stable.zip"
    $url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FlutterVersion-stable.zip"
    Write-Step "下载 $url"
    if (-not (Test-Path $zip)) {
        curl.exe -L --fail --retry 3 -o $zip $url
        if ($LASTEXITCODE -ne 0) { throw "下载失败，请检查网络/代理" }
    }
    Write-Step "解压到 $InstallRoot"
    tar.exe -xf $zip -C $InstallRoot
    if ($LASTEXITCODE -ne 0) { throw "解压失败" }
}

Write-Step "写入用户 PATH"
$bin = Join-Path $FlutterHome 'bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$bin*") {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $bin), 'User')
    Write-Host "已追加：$bin（新终端生效）"
}
$env:Path = "$env:Path;$bin"

Write-Step "配置 Flutter"
flutter config --no-analytics          | Out-Null
flutter config --enable-windows-desktop | Out-Null
flutter --version

Write-Step "环境体检"
flutter doctor

Write-Host @"

--------------------------------------------------------------------
还需要一次性手动步骤：安装 Visual Studio Build Tools（需管理员）

以【管理员】身份打开 PowerShell，粘贴执行：

& '$DownloadDir\vs_buildtools.exe' `` 
  --quiet --wait --norestart --nocache `` 
  --installPath 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools' `` 
  --add Microsoft.VisualStudio.Workload.VCTools `` 
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `` 
  --add Microsoft.VisualStudio.Component.Windows11SDK.22621 `` 
  --includeRecommended

装完执行 flutter doctor -v，Visual Studio 一项应变为 √
--------------------------------------------------------------------
"@ -ForegroundColor Yellow
