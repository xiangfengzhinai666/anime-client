# S1 复验报告

> 日期：2026-11-22 23:45–00:05 · 提交：`5ddf6d3`
> 目的：把 S1 整套流程从零再走一遍，并逐项检测 S0 遗留项，确认"不是靠本地缓存撑着"。

## 结论

| 验证项 | 判据 | 结果 |
|---|---|---|
| 静态分析 | 0 issue | ✅ `No issues found!` |
| 测试 | 全绿 | ✅ **18 个**，干净克隆里 16 s |
| 干净克隆构建 | 可复现 | ✅ clone 4 s → pub get 1 s → analyze 8 s → build 71 s |
| 五页截图 | 与仓库一致 | ✅ **5/5 逐像素 0 差异** |
| 首次运行 | 空数据目录可用 | ✅ 自动建库（3 表 / user_version=1）与日志目录 |
| 冷启动 | < 2 s | ✅ 5 次 1268–1347 ms，均值 1309 |
| 空闲内存 | 无泄漏趋势 | ✅ 120.7 MB，10 s 内不变，CPU 空闲累计 1.56 s |
| S0 环境 | 无漂移 | ✅ doctor 全绿，`bootstrap.ps1 -Check` 8 项 0 失败 |
| 仓库卫生 | 干净 | ✅ 74 文件、无敏感串、UTF-8 全通过、工作区 clean |

## 一、干净克隆（证明仓库自足）

```
$ git clone --depth 1 ... $TMP
clone=4s   提交=5ddf6d3   文件数=74
build 存在=False   .dart_tool 存在=False      ← 没有任何本地缓存

$ flutter pub get     1s    （依赖清单完整）
$ flutter analyze     8s    No issues found!
$ flutter test       16s    00:03 +18: All tests passed!
$ flutter build windows --release   71s   ✓ Built anime_client.exe
```

关键点：`app_database.g.dart`（代码生成产物）在仓库里，所以**克隆后不需要先跑 build_runner** 就能编译。

## 二、截图比对（证明界面可复现）

在干净克隆里用 `DSH_SHOT` 逐页取图，与仓库内 `docs/assets/s1/*.png` 逐像素比对：

```
0-home:    diff_pixels=0  bbox=None
1-browse:  diff_pixels=0  bbox=None
2-search:  diff_pixels=0  bbox=None
3-library: diff_pixels=0  bbox=None
4-profile: diff_pixels=0  bbox=None
```

五张全部**完全一致**——说明界面没有依赖时间、随机数或本机残留数据。

## 三、首次运行（模拟全新机器）

把 `%APPDATA%\anime-client` 整体改名后冷启动（跑完已还原），验证应用能自己把地基铺出来：

| 期望 | 实测 |
|---|---|
| 创建数据目录 | `C:\Users\Asuka\AppData\Roaming\anime-client\Anime Client\` |
| 建库 | `anime_client.sqlite` 24 KB |
| 建表 | `favorite_entries` / `history_entries` / `setting_entries` |
| 主键正确 | history `(bangumi_id, episode)`；favorite `(bangumi_id)`；setting `(key)` |
| schema 版本 | `PRAGMA user_version = 1` |
| 建日志目录 | `logs\app_2026-11-22.log` |
| 启动即写日志 | 首行：`INFO [boot] Anime Client 0.1.0 启动（S1）` |

> 顺便验证了 `.gitignore` 之外的运行时目录不会污染仓库。

## 四、性能与资源

冷启动（进程启动 → 主窗口出现，5 次）：

```
1347, 1327, 1268, 1289, 1313 ms     均值 1309 ms
```

空闲 20 秒后再观察 10 秒：

```
WorkingSet 120.7 MB（10 秒内无变化）
CPU 累计 1.56 s（空闲无自旋）
线程 120
```

结论：启动远低于 2 s 目标；空闲没有内存增长或 CPU 占用，说明没有失控的定时器/动画。

## 五、本轮修的两个问题

| 问题 | 影响 | 处理 |
|---|---|---|
| 日志用 `\n` 换行 | Windows 记事本打开可能显示成一行 | 改用 `Platform.lineTerminator`（CRLF），已验证 LF=2 / CR=2 |
| 布局只在 1400×900 下验证过 | 窄屏/宽屏可能溢出 | 新增 `layout_test.dart`：420/800/1000/1400/1920 五种尺寸遍历五页，任何 overflow 直接失败 |

> 布局测试第一次跑就抓到 420 宽下 hero 按钮溢出 39 px，已改成 `Wrap` + 窄屏隐藏大图标。

## 六、S0 复核（防环境漂移）

```
$ flutter doctor -v
[√] Flutter 3.47.9
[√] Windows 11 25H2
[√] Visual Studio 生成工具 2022 17.14.45 @ C:\sofeware\software\vs-buildtools

$ powershell -File scripts\bootstrap.ps1 -Check
[OK] Flutter / VS / MSVC 14.44 / SDK 10.0.26100 / PATH / 代理 / 磁盘
体检通过：0 项失败
```

## 七、仓库卫生

- 跟踪文件 **74** 个，工作区 `clean`
- 敏感串扫描（password / secret / ghp_ / sk- / BEGIN PRIVATE KEY）：**无命中**
- 全仓库 UTF-8 严格校验：**通过**（无坏字节）

## 八、仍然遗留（不是 bug，是边界）

| 项 | 说明 |
|---|---|
| 业务数据 | 番剧/播放/弹幕都还没有，S2 起接入 |
| 追番写入口 | 表与 DAO 已就绪，界面入口在 S5 |
| `dist/` 便携目录 | 已加入 `.gitignore`，仅供本机试玩；正式打包在 S6 |
| 无原生 UI 自动化 | 目前靠 widget 测试 + 自渲染截图，手感类问题仍需人工试 |

## 九、复验方法（可重复执行）

```powershell
# 1. 环境
powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1 -Check

# 2. 干净克隆验证
git clone --depth 1 https://github.com/xiangfengzhinai666/anime-client.git $env:TEMP\s1-verify
cd $env:TEMP\s1-verify; flutter pub get; flutter analyze; flutter test; flutter build windows --release

# 3. 逐页截图（0–4 对应 首页/索引/搜索/追番/我的）
$env:DSH_SHOT="$PWD\shot.png"; $env:DSH_SHOT_TAB="0"; .\build\windows\x64\runner\Release\anime_client.exe
```
