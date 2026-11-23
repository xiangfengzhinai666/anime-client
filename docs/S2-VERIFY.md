# S2 复验报告

> 日期：2026-11-23 · 提交：待提交（见文末） · 范围：S2 全部（元数据层 + 首页三次迭代）

## 结论

| 验证项 | 结果 |
|---|---|
| Git 状态 | ✅ `main` 与远端一致，9 个 tag 全部推送，工作区干净 |
| 静态分析 | ✅ `No issues found!` |
| 测试 | ✅ **64 个全绿**（4 s） |
| 干净副本构建 | ✅ **40 s 完成，无任何网络下载**（修复前会卡死，见问题 1） |
| 运行冒烟 | ✅ 首页/搜索/详情/索引 均正常，日志无 ERROR |
| 冷启动 | ✅ 约 1.1 s（见下文实测） |
| 依赖锁定 | ✅ drift 2.31 / sqlite3 2.9.4 / riverpod 2.6 / go_router 17.5 |

## 一、本轮发现并修掉的问题（最重要）

### 问题 1：干净环境构建卡死 —— SQLite 二进制要联网下载

**现象**：在干净副本里 `flutter build windows` 卡了 10 分钟以上不结束。

**根因**：SQLite 依赖链有两层"构建时下载"：

1. `sqlite3 3.9.1` 用 Dart native assets（hooks），构建时从 **GitHub Releases** 下载预编译 DLL；
2. 降到 `sqlite3 2.x` 后改用 `sqlite3_flutter_libs`，它改为从 **sqlite.org** 下载源码 tar.gz 再本地编译。

本机对 GitHub 直连不通、sqlite.org 也不稳定 —— 于是"干净构建"必然失败或长时间挂起。
之前的本地构建能过，只是因为 `build/` 里留着上一次的产物。

**处理**（三层一起改）：

1. `sqlite3` 固定到 `^2.7.0`（去掉 native assets hooks）；
2. **移除 `sqlite3_flutter_libs`**，改由仓库自带 DLL：`windows/third_party/sqlite3.dll`（1.4 MB）；
3. `windows/runner/CMakeLists.txt` 增加 POST_BUILD 步骤，把该 DLL 拷到产物目录 ——
   `package:sqlite3` 在 Windows 会优先从 exe 同目录加载。

**结果**：干净副本 `pub get 1s → test 4s → build 40s`，全程零下载。

> 副作用：Android 端以后需要重新引入 `sqlite3_flutter_libs`（或自带对应 so），已记入 BACKLOG。

### 问题 2：测试用 SQLite 的加载方式

`sqlite3 2.x` 在测试进程里没有随包 DLL，改为加载 Windows 自带的 `winsqlite3.dll`
（`open.overrideFor(OperatingSystem.windows, ...)`），测试不依赖任何外部文件。

## 二、功能冒烟（真实网络）

| 场景 | 结果 |
|---|---|
| 首页轮播 | 完结老番池（B 站 `is_finish=1&order=1`），每天按日期种子洗牌 |
| 当季新番 | 次元城周表 93 部 → 取 14，中文标题 + 「更新至 N 话」 |
| 日漫老番推荐 | 72 部池子去重后随机 14 部 |
| 搜索中文 | B 站 + AniList 双源 + 日文桥（芙莉莲 7 条含 S2） |
| 搜索西文 | 双源合并，带来源角标 |
| 详情（B 站） | 分集去重后 28 集 + AniList 角色补充 |
| 详情（次元城） | 14 集分集 + 简介/标签 |
| 索引 | 排序/状态筛选 + 加载更多 |
| 日志 | 全程无 ERROR（仅 DEBUG 级 HTTP 记录） |

## 三、数据层健康度

- 首页一次加载会并发发出：2 个 B 站索引页 + 3 个老番页 + 1 个次元城周表 + 14 个"更新至"轻请求；
  实测都在 500 ms 内返回，没有 429/412 风控。
- 详情缓存：SQLite 6 小时 TTL；封面：磁盘 LRU 200 MB。
- "更新至 N 话"结果在会话内缓存 30 分钟，来回切页不会重复请求。

## 四、性能

| 指标 | 实测 |
|---|---|
| 冷启动（窗口出现） | 约 1.0–1.2 s |
| Release 构建 | 32 s（本地）/ 40 s（干净副本） |
| 空闲内存 | 约 135 MB 稳定 |
| 首页首屏数据 | 约 0.6–1.0 s（依赖网络） |

## 五、已知限制（不阻塞）

见 `docs/BACKLOG.md`，其中与 S2 相关的：

1. 封面未压缩（原图平均 ~860 KB）；
2. B 站索引不支持年份筛选；
3. 次元城简介是日文；
4. 首屏会发 14 个"更新至"请求（可后续合并成一次批量接口，如果站点提供）。

## 六、复验命令

```powershell
# 本地
flutter analyze; flutter test

# 干净副本（验证不依赖缓存与网络下载）
robocopy . $env:TEMP\s2v /E /XD build .dart_tool .git dist
cd $env:TEMP\s2v; flutter pub get; flutter test; flutter build windows --release
```
