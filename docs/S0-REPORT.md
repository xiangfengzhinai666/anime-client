# S0 环境报告

> 日期：2026-11-22 · 执行人：lead（自动化） · 验收人：待确认

## 结论

| 项 | 状态 | 说明 |
|---|---|---|
| Flutter SDK | ✅ 完成 | 3.47.9 stable，`C:\sofeware\software\flutter` |
| Dart | ✅ 完成 | 3.13.7 |
| Windows 桌面目标 | ✅ 完成 | `flutter config --enable-windows-desktop`，devices 中已出现 Windows (desktop) |
| 项目脚手架 | ✅ 完成 | `flutter create --platforms=windows`，org `com.xiangfeng`，包名 `anime_client` |
| 自检窗口 | ✅ 完成 | `lib/main.dart`：信息卡 + 渲染探针 + 交互探针 |
| 静态分析 | ✅ 通过 | `flutter analyze`：No issues found |
| 单元/Widget 测试 | ✅ 通过 | `flutter test`：3/3 |
| Visual Studio Build Tools | ❌ **阻塞** | UAC 授权被取消（等待人工点击） |
| Windows 原生构建/运行 | ⏸ 待验证 | 依赖上一条 |

**S0 未完成**：缺 VS Build Tools（C++ 工作负载 + Windows SDK），因此还不能编译出 exe，也无法做原生窗口截图。

## 已验证的证据

```
Flutter 3.47.9 • channel stable
Framework • revision c197ca5199 (3 weeks ago) • 2026-10-29
Engine • revision 89c39edfdf
Tools • Dart 3.13.7 • DevTools 2.60.0

[√] Flutter (Channel stable, 3.47.9, on Microsoft Windows [版本 10.0.26200.6584], locale zh-CN)
[√] Windows Version (Windows 11 or higher, 25H2, 2009)
[√] Chrome - develop for the web
[√] Connected device (3 available)
    • Windows (desktop) • windows • windows-x64
[X] Visual Studio - develop Windows apps
    X Visual Studio not installed
```

```
$ flutter analyze
No issues found!

$ flutter test
00:00 +3: All tests passed!
```

## 阻断项与解决办法

`vs_buildtools.exe` 以管理员身份启动时弹出 UAC，选择了「否 / 未响应」，安装未执行。

**任选一种解决：**

1. 下一条消息我重试时，屏幕上出现 UAC 弹窗，点「是」；
2. 或你自己以管理员身份打开 PowerShell，粘贴执行：

```powershell
& 'C:\sofeware\software\_dsh_downloads\vs_buildtools.exe' `
  --quiet --wait --norestart --nocache `
  --installPath 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools' `
  --add Microsoft.VisualStudio.Workload.VCTools `
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  --add Microsoft.VisualStudio.Component.Windows11SDK.22621 `
  --includeRecommended
```

预计下载 5–7 GB，10–25 分钟（取决于网速）。

装完自查：

```powershell
& 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe' -latest -products * -property displayName
flutter doctor -v   # Visual Studio 一项应变成 √
```

## 额外说明

- `github.com` 直连不通，git 已配置 `http.proxy=http://127.0.0.1:7897`（Clash）。
- `flutter doctor` 的 Network resources 会报 maven.google.com / github.com 超时：不影响 Windows 构建，仅影响 Android 目标。
- 项目路径含空格（`dsh workspace`），已实测 CMake/构建可用；若后续出现路径问题，优先考虑把仓库移到无空格路径。
