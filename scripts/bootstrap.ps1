# 环境引导 / 体检脚本（可复现 S0）
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1 -Check    # 只体检，不安装
#   powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1          # 安装/修复 Flutter 环境
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$FlutterVersion = '3.47.9'
$InstallRoot    = 'C:\sofeware\software'
$FlutterHome    = Join-Path $InstallRoot 'flutter'
$VsHome         = Join-Path $InstallRoot 'vs-buildtools'
$DownloadDir    = Join-Path $InstallRoot '_dsh_downloads'
$Vswhere        = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Bad($msg)  { Write-Host "  [!!] $msg" -ForegroundColor Red }

function Get-FlutterExe {
    $candidate = Join-Path $FlutterHome 'bin\flutter.bat'
    if (Test-Path $candidate) { return $candidate }
    $c = Get-Command flutter -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

# ---------------------------------------------------------------- 体检模式
if ($Check) {
    Write-Step 'S0 环境体检'
    $fail = 0

    $flutter = Get-FlutterExe
    if ($flutter) {
        $ver = (& $flutter --version 2>&1 | Select-Object -First 1) -join ''
        Write-Ok "Flutter: $ver"
        Write-Ok "路径: $flutter"
    } else {
        Write-Bad '未找到 Flutter'; $fail++
    }

    if (Test-Path $Vswhere) {
        $vsPath = (& $Vswhere -latest -products * -format value -property installationPath 2>&1)
        $vsVer  = (& $Vswhere -latest -products * -format value -property installationVersion 2>&1)
        if ($vsPath) { Write-Ok "VS Build Tools: $vsVer @ $vsPath" } else { Write-Bad '未检测到 VS Build Tools 实例'; $fail++ }
        if ($vsPath -and $vsPath -ne $VsHome) { Write-Host "  [i] 实例不在预期路径（预期 $VsHome），功能可用但不规范" -ForegroundColor Yellow }
    } else {
        Write-Bad '未找到 vswhere（VS Installer 未安装）'; $fail++
    }

    $msvc = Get-ChildItem (Join-Path $VsHome 'VC\Tools\MSVC') -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty Name
    if ($msvc) { Write-Ok "MSVC 工具集: $msvc" } else { Write-Bad "未找到 MSVC（$VsHome\VC\Tools\MSVC）"; $fail++ }

    $sdkLib = 'C:\Program Files (x86)\Windows Kits\10\Lib'
    if (Test-Path $sdkLib) {
        $sdks = (Get-ChildItem $sdkLib | Select-Object -ExpandProperty Name) -join ', '
        Write-Ok "Windows SDK: $sdks"
    } else {
        Write-Bad '未找到 Windows SDK'; $fail++
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    if ($userPath -like '*flutter\bin*') { Write-Ok '用户 PATH 含 flutter\bin' } else { Write-Bad '用户 PATH 缺少 flutter\bin'; $fail++ }

    $proxy = git config --global --get http.proxy 2>$null
    if ($proxy) { Write-Ok "git 代理: $proxy" } else { Write-Host '  [i] git 未配置代理（直连 GitHub 可用时无需）' -ForegroundColor Yellow }

    $free = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
    if ($free -ge 10) { Write-Ok "C 盘可用: ${free} GB" } else { Write-Bad "C 盘可用仅 ${free} GB"; $fail++ }

    if ($fail -eq 0) { Write-Host "`n体检通过：0 项失败" -ForegroundColor Green; exit 0 }
    Write-Host "`n体检失败：$fail 项" -ForegroundColor Red; exit 1
}

# ---------------------------------------------------------------- 安装模式
Write-Step "检查 Flutter SDK（目标版本 $FlutterVersion）"
if (Test-Path (Join-Path $FlutterHome 'bin\flutter.bat')) {
    Write-Host "已存在：$FlutterHome"
} else {
    New-Item -ItemType Directory -Path $InstallRoot, $DownloadDir -Force | Out-Null
    $zip = Join-Path $DownloadDir "flutter_windows_$FlutterVersion-stable.zip"
    $url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FlutterVersion-stable.zip"
    Write-Step "下载 $url"
    if (-not (Test-Path $zip)) {
        curl.exe -L --fail --retry 3 -o $zip $url
        if ($LASTEXITCODE -ne 0) { throw '下载失败，请检查网络/代理' }
    }
    Write-Step "解压到 $InstallRoot"
    tar.exe -xf $zip -C $InstallRoot
    if ($LASTEXITCODE -ne 0) { throw '解压失败' }
}

Write-Step '写入用户 PATH'
$bin = Join-Path $FlutterHome 'bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$bin*") {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $bin), 'User')
    Write-Host "已追加：$bin（新终端生效）"
}
$env:Path = "$env:Path;$bin"

Write-Step '配置 Flutter'
flutter config --no-analytics           | Out-Null
flutter config --enable-windows-desktop | Out-Null
flutter --version

Write-Step '环境体检'
flutter doctor

Write-Host @"

--------------------------------------------------------------------
还需要一次性手动步骤：安装 Visual Studio Build Tools（需管理员）

以【管理员】身份打开 PowerShell，粘贴执行：

`$vsArgs = '--quiet --wait --norestart --installPath "$VsHome" ' +
          '--add Microsoft.VisualStudio.Workload.VCTools ' +
          '--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ' +
          '--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended'
Start-Process '$DownloadDir\vs_buildtools.exe' -ArgumentList `$vsArgs -Verb RunAs -Wait

注意：--installPath 的值必须带引号，且整个参数列表作为【一个字符串】传入，
否则路径里的空格会把安装目录拆坏（S0 踩过这个坑）。

装完执行： powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1 -Check
--------------------------------------------------------------------
"@ -ForegroundColor Yellow
