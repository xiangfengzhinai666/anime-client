# S3 报告：播放器

> 日期：2026-11-23 · 阶段：S3（播放器 + 源级登录 + 本地文件源）

## 一、做了什么

| 模块 | 内容 |
|---|---|
| 依赖体检 | `media_kit` 1.2.6 + `media_kit_video` 2.0.1 + libmpv/ANGLE（**仓库自带归档，构建不联网**） |
| 源级登录 | 次元城 **用户名 + 密码** 登录，token 存 **Windows 凭据管理器**，过期自动续期 |
| 播放地址 | `GET /api/v2/sections/{sectionId}/play-url` → 线路列表（兼容 3 种返回形状） |
| 播放页 | `/watch/{source}:{id}/{ep}`、`/watch/local?path=…` |
| 播放控制 | 播放/暂停、进度条（含拖动）、上/下一集、倍速（0.5–2.0）、音量、全屏、选集面板、线路切换 |
| 快捷键 | 空格/K 暂停、←/→ ±5s、J/L ±10s、↑/↓ 音量、M 静音、F 全屏、Esc 退出/返回 |
| 续播 | 每 5 秒写 `history`，进播放页自动 seek 上次位置 |
| 容错 | 未登录 → 引导登录；无线路 → 重试；播放错误 → 错误面板 |
| 本地文件源 | 设置 →「打开本地视频」（file_selector），不需要任何账号 |
| 详情联动 | 详情页「从第 1 集开始」和分集按钮直接进播放页 |

## 二、关键决策（含踩坑）

### 1. media_kit 的 libmpv/ANGLE 也会联网下载

`media_kit_libs_windows_video` 在 CMake 配置阶段从 **GitHub Releases** 下载
`mpv-dev-x86_64-….7z`（29 MB DLL）和 `ANGLE.7z`。本机 GitHub 直连不通，干净构建会挂。

**处理**：把两个归档（共 14 MB）放进 `windows/third_party/mpv/`，
在 `windows/CMakeLists.txt` 里于插件加载前 `configure_file` 拷到 `${CMAKE_BINARY_DIR}`。
插件会校验 MD5（`a832ef…` / `e866f1…`）——校验通过就跳过下载，直接解压。
与 S2 的 sqlite3 处理同一套路，**干净副本 40–55 s 构建，零下载**。

### 2. `flutter_secure_storage` 在这台机器编译不过

它的 Windows 实现需要 **ATL**（`atlstr.h`），本机 VS Build Tools 没装，编译直接失败。

**处理**：改用 `win32` 包直接调 **Windows 凭据管理器**
（`CredWriteW` / `CredReadW` / `CredDeleteW`，DPAPI 按当前用户加密）。
不新增原生依赖，token 依然加密落盘。

### 3. 登录用「用户名 + 密码」

抓站点前端 bundle 得到真实接口：

```
POST /api/auth/login      {username, password}        → {token, user, expires_at}
POST /api/auth/refresh    Authorization: Bearer ...   → {token, expires_at}
POST /api/v2/auth/register {username, password, email, email_code}
POST /api/auth/send-code   {email, type: register|reset}
```

实测：错误凭据返回 `401 invalid username or password`；传 `email` 字段会报
`Username is a required field` —— 确认是 **username** 而不是邮箱。

**为什么不用邮箱验证码登录**：站点登录本身就是用户名密码；验证码只用于注册/找回。
少一个邮件依赖，也少一条失败路径。注册入口后续放设置页说明（去官网注册）。

### 4. 登录态不共享

每个用户在自己的机器上登录自己的次元城账号；token 只在本机凭据管理器里，
不上传、不写日志、不进代码。

## 三、验收

| 项 | 结果 |
|---|---|
| analyze | ✅ 0 issue |
| 测试 | ✅ **72 个全绿**（新增 8 个：播放地址解析 5 + 登录态 3） |
| 构建 | ✅ Release 32 s（干净副本 40–55 s，无下载） |
| 本地播放 | ✅ 实拍截图：sample.mp4 正常解码出画面 |
| 未登录态 | ✅ 播放页显示「需要登录次元城 + 登录按钮」 |
| 设置页 | ✅ 账号区（未登录/登录）、播放区（打开本地视频） |
| 在线播放 | ✅ **已实测**：登录后播放《无职转生 第三季》第 1 集出画面 |

截图：`docs/assets/s3/{0-settings,1-player-need-login,2-local-play}.png`。

## 四、登录后仍不能播放：三个 bug（已修）

用户实测反馈「登录了还是提示需要登录」，排查出三个独立问题：

| # | 根因 | 现象 | 修法 |
|---|---|---|---|
| 1 | **token 自带 `Bearer ` 前缀**，发送时又拼了一次 → `Bearer Bearer eyJ…` | 所有鉴权请求 401，日志里根本没有 play-url 请求 | `CycaniSession.normalizeToken()` 统一剥前缀（登录/恢复/续期/发送四处） |
| 2 | **Riverpod 缓存了失败结果** | 登录前失败的错误被缓存，登录后重试仍是旧错误 | 播放页改用 `ref.refresh`；登录/退出时 `ref.invalidate(playLinesProvider)` |
| 3 | **启动时恢复登录态是异步的** | 冷启动后立刻点播放，会误判为未登录 | `CycaniAuth.ensureLoaded()`，取播放地址前显式等一次 |

**验证**：修复后 `cycani-play-url` 返回 200，播放《无职转生 第三季》第 1 集正常出画面
（`docs/assets/s3/3-online-play.png`）。

> 顺带确认：播放地址形如 `https://xxx.cycstream.com/<base64>.mp3?expires=…&md5=…`，
> 实际是 **mp4**（Content-Type `video/mp4`，文件头 `ftypisom`），扩展名是防盗链伪装，播放器按内容识别。

## 五、已知限制

1. 全屏用 `window_manager`（**锁在 0.5.x**，0.6 是重写版 API 不兼容）。
3. 选集面板是底部弹窗，暂不支持「自动连播下一集」。
4. 播放器暂不显示弹幕（S4）。
5. 本地文件只做单文件播放，不做播放列表/文件夹。

## 六、下一步（S4 弹幕）

- 次元城/B 站弹幕拉取与解析
- 自研渲染层（Canvas 绘制，支持透明度/字号/速度/屏蔽词）
- 与播放器时间轴同步、开关、密度限制
