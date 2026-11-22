# S0 复验报告（R0–R5）

> 日期：2026-11-22 22:30–23:0x · 目的：把 S0 整套流程**从零再走一遍**，确认每一步都不是"本地缓存凑巧撑着"。
> 结论：**全部通过**，并顺带完成了品牌图标替换。

## 零、这轮在验证什么

| 假成功 | 可能的真相 | 本轮怎么证伪 | 结果 |
|---|---|---|---|
| 本地能跑 | 有文件没提交 / 依赖没写进 pubspec | 克隆到全新目录，从零构建 | ✅ 31 s 构建成功 |
| 有缓存能跑 | build/、.dart_tool 残留 | 克隆目录里根本没有这些 | ✅ 确认不存在 |
| 文档命令能敲 | 路径或参数写错 | 照文档实跑 | ✅ 全部可执行 |
| 忽略规则没生效 | .gitignore 漏项 | `git check-ignore` + 扫描 | ✅ 生效 |
| 换图标把构建搞坏 | ICO/RC 语法错 | 替换后全量重建 + 启动截图 | ✅ 正常 |

## 一、R0 环境体检

| 项 | 实测值 |
|---|---|
| Flutter | 3.47.9 stable（revision c197ca5199） |
| Dart | 3.13.7 |
| VS Build Tools | 17.14.37906.3 @ `C:\sofeware\software\vs-buildtools` |
| MSVC | 14.44.35207 |
| Windows SDK | 10.0.26100.0（另有 10.0.22621.0） |
| Windows | 11 25H2（10.0.26200） |
| git 代理 | `http://127.0.0.1:7897` |
| 用户 PATH | 含 `flutter\bin` |
| 磁盘 | C: 222.6 GB 可用 |
| 硬件 | Ryzen 9 7845HX / 24 线程 / 15.2 GB |

`flutter doctor`：Flutter ✓ / Windows ✓ / Visual Studio ✓ / Chrome ✓（Android 未装，属计划内）。

## 二、R1 干净克隆构建

克隆到 `%TEMP%\s0-verify`（深度 1），该目录**没有 build/ 与 .dart_tool/**：

| 步骤 | 耗时 | 结果 |
|---|---|---|
| `git clone` | 3 s | 32 个跟踪文件 |
| `flutter pub get` | 1 s | 依赖齐全，无缺失 |
| `flutter analyze` | 9 s | **No issues found** |
| `flutter test` | 8 s | **3/3 passed** |
| `flutter build windows --release` | 31 s | 产出 exe |
| 启动 + 自截图 | — | exit 0 |
| 冷启动（到窗口出现） | — | **1143 ms** |

**截图比对**（克隆产物 vs 仓库内 `docs/assets/s0-selfcheck.png`）：

```
尺寸一致 1246×823
差异像素 441 / 1025458 = 0.043%
差异区域 (468,418)-(553,428)  ← 只有「启动时刻」这 85×10 的时间戳
```

结论：除时间戳外**逐像素一致**，说明仓库内容足以复现同一界面。

## 三、R2 脚本可用性

给 `scripts/bootstrap.ps1` 增加了 `-Check` 模式（只体检、不下载），实跑：

```
==> S0 环境体检
  [OK] Flutter: Flutter 3.47.9 • channel stable
  [OK] 路径: C:\sofeware\software\flutter\bin\flutter.bat
  [OK] VS Build Tools: 17.14.37906.3 @ C:\sofeware\software\vs-buildtools
  [OK] MSVC 工具集: 14.44.35207
  [OK] Windows SDK: 10.0.22621.0, 10.0.26100.0
  [OK] 用户 PATH 含 flutter\bin
  [OK] git 代理: http://127.0.0.1:7897
  [OK] C 盘可用: 222.3 GB
体检通过：0 项失败
```

顺带修正：本机**没有 PowerShell 7**，文档里的 `pwsh` 全部改成 `powershell`；脚本改存 UTF-8 BOM，避免 5.1 按 ANSI 读中文报解析错误。

## 四、R3 仓库卫生

| 检查 | 结果 |
|---|---|
| `git status` | 仅预期的改动，无游离文件 |
| 跟踪文件数 | 32 |
| `.gitignore` 生效 | `build/` `.dart_tool/` `.idea/` 均被忽略（`git check-ignore -v` 验证） |
| 敏感串扫描（排除 docs） | 无 `password=` / `secret=` / `ghp_` / `sk-` / `BEGIN PRIVATE KEY` 命中 |
| 凭据类文件 | 无 `.pem/.key/.p12/.pfx/.jks/.keystore` 被跟踪 |
| tag | `s0-env`、`s0-env2` 均在远端 |
| remote | `https://github.com/xiangfengzhinai666/anime-client.git` |

## 五、R4 品牌图标

**选图**：`Desktop\photograph  素材\素材\preview.jpg`（1024×1024 原图，单张脸 + 暖光，16px 下仍有明暗轮廓）。
裁切参数：84% 居中偏上（`left=30, top=0`），保留头部完整、脸占比更大，小尺寸更清晰。

**产出**：

| 产物 | 位置 | 说明 |
|---|---|---|
| 源图归档 | `assets/branding/app_icon.png` | 1024×1024，入库 |
| Windows 图标 | `windows/runner/resources/app_icon.ico` | 7 档：16/24/32/48/64/128/256，PNG 负载手写 ICO |
| 各尺寸对照 | `docs/assets/icon-preview.png` | 浅/深底各一组 |
| 内嵌验证 | `docs/assets/icon-sizes.png` | 从 **exe 里抽出**的图标 vs ICO 256 档 |

**应用内**：自检页 header 从"蓝紫渐变 + 播放图标"换成同一张图（56×56，圆角 16，带阴影）。

**exe 元数据**：

```
ProductName      = Anime Client
FileDescription  = Anime Client
CompanyName      = anime-client
OriginalFilename = anime_client.exe
```

**构建**：`flutter build windows --release` 20 s，启动截图见 `docs/assets/s0-selfcheck.png`。

**换图工具**：`scripts/gen_icon.py`（本轮新增并实测）——给定一张图，自动裁切、生成 1024 PNG、
七档 ICO（每档独立重采样 + 小尺寸锐化）、浅/深底对照图。换图标从此是一条命令的事：

```powershell
python scripts/gen_icon.py "D:\pics\fav.jpg" --crop 0.84 --left 30 --top 0
flutter build windows --release
```

## 六、R5 归档

- 提交与 tag 见仓库历史
- 截图已更新为品牌版

## 七、遗留（非缺陷）

| 项 | 说明 |
|---|---|
| Android 工具链 | 未装，Tier 3 前处理 |
| 安装器 / 签名 | S6 |
| 图标版权 | 素材为个人收藏，仅本机自用，不分发 |
| 图标可替换 | `python scripts/gen_icon.py <图片> --crop 0.84` 一条命令重建 PNG + ICO + 对照图，再 `flutter build windows --release` 即可 |

## 八、复验结论

S0 的五个环节（环境、仓库自足性、脚本、仓库卫生、品牌资源）**全部通过可重放验证**。
下一段 S1 可以在此基础上开始，不需要回头修地基。
