# 工具链（S0 冻结）

本文件记录项目地基的**确切版本与路径**。S0 之后不随意升级；升级需单独开一段并回归。

## 冻结版本

| 组件 | 版本 | 说明 |
|---|---|---|
| Flutter | **3.47.9** (stable) | 2026-10-29 发布，上一 minor 线最后一个补丁版 |
| Dart | 3.13.7 | 随 Flutter 附带 |
| Visual Studio Build Tools | 2022 (17.x) | 仅 C++ 桌面工作负载，不带完整 IDE |
| Windows SDK | 10.0.22621 或更高 | vs_buildtools 一并安装 |
| CMake / Ninja | 随 VS Build Tools | Flutter Windows 构建依赖 |

> **为什么不用最新的 3.50.1**：它 2026-11-20 才发布（两天前）。地基版本优先选"上一个 minor 线的最后一个补丁版"——bug 已收口、插件生态已完成适配。后续要升 3.5x，单独排期验证。

## 安装位置

| 内容 | 路径 |
|---|---|
| Flutter SDK | `C:\sofeware\software\flutter` |
| VS Build Tools | `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools` |
| 项目 | `C:\sofeware\AI Api\dsh workspace\workspace\anime` |
| 下载缓存 | `C:\sofeware\software\_dsh_downloads`（可不入库） |

## 网络与代理

这台机器**直连 github.com 不通**（443 超时），所有 GitHub 操作依赖本机代理 `127.0.0.1:7897`。

```powershell
# 查看当前代理
git config --global --get http.proxy

# 代理开启时
git config --global http.proxy  http://127.0.0.1:7897
git config --global https.proxy http://127.0.0.1:7897

# 代理关闭时（切回直连）
git config --global --unset http.proxy
git config --global --unset https.proxy
```

`flutter pub get` 走 pub.dev（可直连）；但若依赖里有 `git:` 源，需要代理。

## 常用命令

```powershell
flutter doctor -v                 # 环境体检
flutter devices                   # 应能看到 Windows (desktop)
flutter pub get                   # 拉依赖
flutter run -d windows            # 开发运行
flutter build windows --release   # 出包
flutter test                      # 单元 + golden 测试
```

## 构建前置条件（自查）

- [ ] `flutter doctor` 里 Visual Studio 一项为 ✓（不是 "!"）
- [ ] 系统启用**长路径**（注册表 `LongPathsEnabled=1`），Flutter 构建路径较深
- [ ] 项目路径**不含中文/空格以外的特殊字符**（本项目路径含空格，已实测可用）
- [ ] 代理在需要拉 GitHub 依赖时开启

## 已知坑

| 现象 | 原因 | 处理 |
|---|---|---|
| `git push` 卡 20 秒后超时 | 直连 GitHub | 配 http.proxy 走 7897 |
| `flutter doctor` 显示 VS 不完整 | 缺 Windows SDK 或 C++ 工作负载 | 补装 `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` + Windows SDK |
| CMake 找不到编译器 | 未安装 VCTools 工作负载 | 同上 |
| 构建报长路径错误 | 未启用 LongPaths | 开注册表项后重启终端 |
