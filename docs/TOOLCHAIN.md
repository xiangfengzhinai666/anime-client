# 工具链（S0 冻结）

本文件记录项目地基的**确切版本与路径**。S0 之后不随意升级；升级需单独开一段并回归。

## 冻结版本

| 组件 | 版本 | 说明 |
|---|---|---|
| Flutter | **3.47.9** (stable) | 2026-10-29 发布，上一 minor 线最后一个补丁版 |
| Dart | 3.13.7 | 随 Flutter 附带 |
| Visual Studio Build Tools | **2022 17.14.37906.3** | 仅 C++ 桌面工作负载 |
| MSVC 工具集 | 14.44.35207 | `<VS>\VC\Tools\MSVC\14.44.35207` |
| Windows SDK | **10.0.26100.0** | `C:\Program Files (x86)\Windows Kits\10`（系统标准位置） |
| CMake / Ninja | 随 VS Build Tools | Flutter Windows 构建依赖 |

> **为什么不用最新的 Flutter 3.50.1**：它 2026-11-20 才发布（两天前）。地基版本优先选"上一个 minor 线的最后一个补丁版"——bug 已收口、插件生态已完成适配。要升 3.5x 单独排期验证。

## 安装位置

| 内容 | 路径 |
|---|---|
| Flutter SDK | `C:\sofeware\software\flutter` |
| **VS Build Tools** | **`C:\sofeware\software\vs-buildtools`** |
| Windows SDK | `C:\Program Files (x86)\Windows Kits\10`（保持系统标准位置，不搬） |
| 项目 | `C:\sofeware\AI Api\dsh workspace\workspace\anime` |
| 下载缓存 | `C:\sofeware\software\_dsh_downloads`（不入库） |

VS 安装目录内部结构（供排查参考）：

```
C:\sofeware\software\vs-buildtools\
  Common7\      MSBuild、辅助工具
  VC\           MSVC 编译器与库
  MSBuild\
  SDK\ DIA SDK\ ...
```

## 装 VS Build Tools（含一个必须踩过的坑）

```powershell
# ✅ 正确：整个参数列表作为【一个字符串】传入，路径自带引号
$vsArgs = '--quiet --wait --norestart --installPath "C:\sofeware\software\vs-buildtools" ' +
          '--add Microsoft.VisualStudio.Workload.VCTools ' +
          '--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ' +
          '--add Microsoft.VisualStudio.Component.Windows11SDK.22621 ' +
          '--includeRecommended'
Start-Process 'C:\sofeware\software\_dsh_downloads\vs_buildtools.exe' -ArgumentList $vsArgs -Verb RunAs -Wait

# ❌ 错误：数组会被用空格拼接且不加引号，路径被拆开
# Start-Process $exe -ArgumentList @('--installPath','C:\Program Files (x86)\...') -Verb RunAs
```

**复盘**：S0 第一次安装用了数组形式，`C:\Program Files (x86)\...` 被拆成
`C:\Program` + `Files` + `(x86)\...`，VS 实际装进了 `C:\Program`（3.4 GB）。
功能没坏（Flutter 靠 `vswhere` 定位），但路径不规范。已通过
`setup.exe uninstall --installPath "C:\Program"` 卸载后按上述正确写法重装到
`C:\sofeware\software\vs-buildtools`，`vswhere` 与 `flutter doctor` 均已指向新路径。

卸载命令（需要管理员）：

```powershell
& 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe' uninstall `
  --installPath '<旧路径>' --quiet --norestart
```

## 网络与代理

这台机器**直连 github.com 不通**（443 超时），GitHub 相关操作依赖本机代理 `127.0.0.1:7897`。

```powershell
# 查看
git config --global --get http.proxy

# 代理开启时
git config --global http.proxy  http://127.0.0.1:7897
git config --global https.proxy http://127.0.0.1:7897

# 代理关闭时（切回直连）
git config --global --unset http.proxy
git config --global --unset https.proxy
```

`pub.dev`、`storage.googleapis.com`、微软 CDN 可直连；GitHub 必须走代理。

## 常用命令

```powershell
flutter doctor -v
flutter devices
flutter pub get
flutter run -d windows
flutter build windows --release
flutter test
```

## 开发期截图（本机自动化验证用）

本机无法稳定抓取 GPU 合成窗口（`PrintWindow` 得到白屏、`CopyFromScreen` 在锁屏/无桌面会话时失败），
因此应用内置**自渲染截图**开关：

```powershell
$env:DSH_SHOT = "C:\path\shot.png"
$env:DSH_SHOT_DELAY_MS = "900"   # 可选，首帧后等待毫秒数
.\build\windows\x64\runner\Release\anime_client.exe
# 首帧渲染 → 写出 PNG → 自动退出（exit 0）
```

实现见 `lib/dev/screenshot.dart`。抓的是 Flutter 自己绘制的帧，与肉眼所见一致。

## 已知坑

| 现象 | 原因 | 处理 |
|---|---|---|
| `git push` 卡 20 秒后超时 | 直连 GitHub | 配 `http.proxy` 走 7897 |
| VS 装到了奇怪路径（如 `C:\Program`） | `Start-Process -ArgumentList` 数组不加引号 | 用单字符串传参，见上 |
| `flutter doctor` 报 maven.google.com/github.com 超时 | doctor 的网络探测不走系统代理 | 不影响 Windows 构建 |
| `.ps1` 报"禁止运行脚本" | 执行策略 Restricted | `pwsh -ExecutionPolicy Bypass -File` |
| `.ps1` 里中文导致解析报错 | Windows PowerShell 5.1 按 ANSI 读无 BOM 文件 | 用 pwsh 7，或存为 UTF-8 with BOM |
| `flutter build` 后换了 VS 路径仍沿用旧缓存 | CMake 缓存记录了旧工具链 | `flutter clean` 后重建 |
