# S0 环境报告

> 日期：2026-11-22 · 状态：**✅ 完成**
> 修订：2026-11-22 22:25 · VS Build Tools 已从误装路径 `C:\Program` 卸载，重装到 `C:\sofeware\software\vs-buildtools`

## 结论

| 项 | 状态 | 证据 |
|---|---|---|
| Flutter SDK | ✅ | 3.47.9 stable，`C:\sofeware\software\flutter` |
| Dart | ✅ | 3.13.7 |
| VS Build Tools | ✅ | 2022 17.14.37906.3 @ `C:\sofeware\software\vs-buildtools` |
| Windows SDK | ✅ | 10.0.26100.0（系统标准位置） |
| Windows 桌面目标 | ✅ | `flutter devices` 有 `Windows (desktop) windows-x64` |
| 项目脚手架 | ✅ | org `com.xiangfeng`，包 `anime_client`，仅 Windows 平台 |
| 自检窗口 | ✅ | 信息卡 / 渲染探针 / 交互探针 |
| 静态分析 | ✅ | `No issues found!` |
| 测试 | ✅ | 3/3 passed |
| Release 构建（`flutter clean` 后冷构建） | ✅ | 35 s |
| 冷启动 | ✅ | 窗口出现 **1081 ms** |
| 截图验证 | ✅ | `docs/assets/s0-selfcheck.png` |

## 验证输出

```
$ flutter doctor -v
[√] Flutter (Channel stable, 3.47.9, on Microsoft Windows [版本 10.0.26200.6584], locale zh-CN)
[√] Windows Version (Windows 11 or higher, 25H2, 2009)
[√] Visual Studio - develop Windows apps (Visual Studio 生成工具 2022 17.14.45)
    • Visual Studio at C:\sofeware\software\vs-buildtools
    • Windows 10 SDK version 10.0.26100.0
[√] Windows (desktop) • windows • windows-x64

$ flutter analyze
No issues found!

$ flutter test
00:01 +3: All tests passed!

$ flutter clean && flutter pub get && flutter build windows --release
√ Built build\windows\x64\runner\Release\anime_client.exe      (35 s)
```

## 界面

![S0 自检窗口](assets/s0-selfcheck.png)

验证到的渲染能力：中文/日文/拉丁字体回退、渐变与圆角、Material 图标、深色主题、
可滚动布局、输入框、按钮与 SnackBar、SelectableText 选中复制。

## 修正记录（2026-11-22）

| 时间 | 动作 | 结果 |
|---|---|---|
| 21:00 | 首次安装 VS Build Tools | 因 PowerShell 参数不加引号，装到了 `C:\Program`（3.43 GB） |
| 22:04 | `setup.exe uninstall --installPath "C:\Program"` | 退出码 0；`C:\Program` 已消失；Windows SDK 被一并卸载 |
| 22:07 | 用**单字符串参数**重装到 `C:\sofeware\software\vs-buildtools` | 退出码 0；3.43 GB；SDK 自动恢复 |
| 22:20 | `flutter clean` + 全量构建 + 截图 | 构建 35 s，界面与重装前完全一致，冷启动 1081 ms |

`vswhere` 与 `flutter doctor` 现均指向 `C:\sofeware\software\vs-buildtools`；`C:\Program` 已不存在。

## 遗留（按计划延后，非缺陷）

- **Android 工具链**：Android SDK / JDK 未装，计划在 Tier 3 前安装
- **代码签名、安装器**：S6
- **VS 包缓存**：`C:\ProgramData\Microsoft\VisualStudio\Packages` 保留（便于修复/离线重装，约 2–3 GB）

## 下一步（S1 骨架）

1. 目录分层：`app/`（主题、路由、DI）、`core/`（http、日志、存储）、`features/`、`source/`、`danmaku/`
2. Material 3 主题（深/浅色 + 动态取色）、字体策略
3. 五个主页面骨架：首页 / 索引 / 搜索 / 追番 / 我的
4. 本地库：drift(SQLite) 建库 + 迁移框架 + 三张表（历史 / 追番 / 设置）
5. 日志与全局错误兜底（未捕获异常 → 落地 + 提示）
6. 验收：五页可切换、冷启动 < 2 s、截图 5 张、测试 ≥ 6 个、analyze 零告警
