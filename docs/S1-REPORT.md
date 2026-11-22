# S1 骨架报告

> 日期：2026-11-22 23:0x–23:3x · 状态：**✅ 完成**
> 目标：把"壳"搭起来（分层 / 主题 / 导航 / 本地库 / 日志与兜底），为 S2 接入数据做准备。

## 一、结论

| 验收项 | 目标 | 实际 | 结果 |
|---|---|---|---|
| 静态分析 | 0 issue | `No issues found!` | ✅ |
| 测试 | ≥ 6 个 | **12 个全绿**（2 s） | ✅ |
| 五页可切换 | 是 | 宽屏侧栏 + 窄屏底栏，tab 状态保持 | ✅ |
| 冷启动 | < 2 s | **1135 ms**（3 次：1139/1109/1156） | ✅ |
| Release 构建 | 通过 | 27 s | ✅ |
| 截图 | 5 张 | `docs/assets/s1/0–4-*.png` | ✅ |
| 数据库 | 三表 + 迁移 | history / favorites / settings，schemaVersion=1 | ✅ |
| 错误兜底 | 三层 | Flutter / Platform / ErrorWidget | ✅ |

代码量：`lib` 28 个 Dart 文件、4172 行；`test` 229 行。

## 二、分层结构（这就是后续所有功能的落点）

```
lib/
├─ main.dart                 # 启动顺序：绑定 → 兜底 → 日志 → 数据库 → runApp → 截图钩子
├─ app/
│  ├─ providers/             # Riverpod 依赖注入（db / dao / theme）
│  ├─ routing/               # go_router：StatefulShellRoute（每个 tab 独立栈）
│  ├─ shell/                 # AppShell：宽屏侧栏 / 窄屏底栏
│  ├─ theme/                 # 设计令牌 + Material3 双主题
│  └─ widgets/               # PageScaffold / EmptyState / SectionHeader / PlaceholderGrid
├─ core/
│  ├─ constants/             # AppInfo（名称/版本/阶段）
│  ├─ error/                 # 全局兜底 + 兜底视图
│  ├─ logging/               # 分级日志：内存环形缓冲 + 按天切分文件
│  ├─ storage/               # drift：tables / app_database / daos
│  └─ utils/                 # 路径、开发环境开关
├─ features/                 # 按功能切：home / browse / search / library / profile / settings
└─ dev/                      # 自渲染截图（DSH_SHOT）
```

**约定**：`features` 不直接碰 drift，只通过 `app/providers` 暴露的 DAO 与 Stream；`core` 不知道任何 UI。

## 三、数据库

三张表（`lib/core/storage/tables.dart`）：

| 表 | 主键 | 字段 | 用途 |
|---|---|---|---|
| `history_entries` | (bangumiId, episode) | 标题、集标题、封面、进度秒、总时长、更新时间 | 续播 / 首页"继续观看" |
| `favorite_entries` | bangumiId | 标题、封面、category(want/watching/watched)、总集数、更新时间 | 追番三态 |
| `setting_entries` | key | value | 主题、后续播放/弹幕偏好 |

几个刻意的决定：

1. **DateTime 存 ISO 文本**（`build.yaml` 里 `store_date_time_values_as_text: true`）。默认按秒存整数，同一秒写入的两条记录排序会乱——S1 的测试当场抓到了这个 bug。
2. **主键就是业务键**（番+集 / 番），`insertOnConflictUpdate` 天然实现"覆盖式进度保存"，不需要先查后写。
3. **迁移框架已就位**：`onUpgrade` 里留了注释模板，以后加字段按 `if (from < n)` 逐版本写，禁止重建表丢数据。
4. 打开失败会**降级到内存库**并记 error 日志，保证界面仍可用（数据不持久）。

## 四、主题与设计令牌

- 令牌集中在 `app_tokens.dart`：间距 / 圆角 / 动效时长 / 尺寸 / 品牌色。页面里没有魔法数字。
- 双主题由同一品牌种子色派生（`ColorScheme.fromSeed`），深色用 `#0E0E12` 背景 + `#16161D` 表面 + `#262633` 描边，与 S0 自检页视觉一致。
- 不加载自定义字体：中文走系统字体回退，避免打包体积与缺字问题。
- 设置页可切「跟随系统 / 浅色 / 深色」，**写入 settings 表**，重启保持（有测试覆盖）。

## 五、导航

- `go_router` + `StatefulShellRoute.indexedStack`：五个一级页面各有独立导航栈，切换 tab 不丢状态。
- 断点 900 px：宽屏左侧 `NavigationRail`（顶部品牌图标、底部设置入口），窄屏 `NavigationBar`。
- `/settings` 在 shell 之外，是全屏二级页。
- **为 S2 铺路**：详情页/播放页将以 `/bangumi/:id`、`/watch/:id/:ep` 挂在对应 branch 上，天然支持返回栈与深链接。

## 六、日志与错误兜底

| 通道 | 处理 |
|---|---|
| 构建/布局/绘制异常 | `FlutterError.onError` → 落日志（debug 下同时红屏） |
| 引擎未捕获异常 | `PlatformDispatcher.onError` → 落日志并返回 true |
| 单块 Widget 崩 | `ErrorWidget.builder` → 友好视图（不依赖 Theme/Provider） |
| Zone 异步异常 | `runZonedGuarded` |

日志：内存环形缓冲 500 条 + 控制台 + 文件（`数据目录/logs/app_YYYY-MM-DD.log`，按天切分、保留 5 天）。设置页「诊断」区实时显示最近 5 条，验证链路可用。

## 七、测试（12 个）

| 文件 | 覆盖 |
|---|---|
| `app_shell_test.dart` | 宽屏侧栏、窄屏底栏、切索引、切追番三页签、主题切换并落库 |
| `storage_test.dart` | 历史写入/倒序/覆盖、按集删除与清空、追番分类查询与更新、设置读写 |
| `logger_test.dart` | 环形缓冲淘汰、minLevel 过滤、格式化输出 |

### 测试踩到的两个真问题（已修）

1. **排序错乱**：DateTime 按秒存整数 → 同秒记录顺序随机。改用文本存储后通过。
2. **`timersPending` 断言**：drift 的流查询持有定时器，组件树卸载后仍存在。测试里显式 `pumpWidget(SizedBox)` 收尾解决，这条也写进了测试 helper。

## 八、没做的（明确边界）

| 项 | 计划 |
|---|---|
| 番剧数据（首页/索引/搜索/详情） | **S2** |
| 播放器 + 第一个源适配器 | **S3** |
| 弹幕引擎 | **S4** |
| 追番操作入口（详情页收藏按钮） | **S5**（表结构已就绪） |
| 下载、PIP、快捷键、通知 | **S6 / S7** |
| 设置页的播放/弹幕偏好 | S3 / S4 随功能补齐 |
| 多语言、无障碍完整覆盖 | 暂不做（个人自用、单语言） |
| Android 端 | Tier 3 |

## 九、下一段 S2 预告

1. 网络层：`dio` 客户端、超时/重试、UA、错误映射
2. 元数据源：B 站接口（搜索 / 索引 / 详情 / 剧集），DTO + 缓存
3. 页面填充：首页推荐位、索引筛选与分页、搜索结果网格、详情页（新路由 `/bangumi/:id`）
4. 图片：带缓存的封面加载（磁盘 LRU + 占位/错误态）
5. 验收：真实搜索出结果、索引可翻页、详情可打开、冷启动仍 < 2 s、测试 ≥ 20
