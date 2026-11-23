# 第三方组件与许可

本项目自身代码使用 [MIT](LICENSE) 许可。

仓库里随包携带了以下**二进制/归档**，它们各有自己的许可，分发时请保留本说明：

| 组件 | 用途 | 许可 | 上游 |
|---|---|---|---|
| libmpv（`mpv-dev-x86_64-20230924-git-652a1dd.7z`） | 播放内核（`media_kit` 依赖） | GPLv2+ / LGPL（取决于构建选项） | https://github.com/mpv-player/mpv |
| ANGLE（`ANGLE.7z`） | Windows 上把 OpenGL ES 转到 D3D | BSD-3-Clause | https://chromium.googlesource.com/angle/angle |
| SQLite（`sqlite3.dll`） | 本地数据库（`drift` 依赖） | Public Domain | https://sqlite.org |
| Media Kit | Flutter 播放器封装 | MIT | https://github.com/media-kit/media-kit |

## 说明

- 仓库里包含这些二进制只是为了「**离线可构建**」：本机无法直连 GitHub Releases，
  构建时若现下载就会失败（详见 `docs/TOOLCHAIN.md`）。
- 若你要再分发本项目的构建产物，请自行确认上述组件的许可义务
  （尤其是 libmpv 的 GPL/LGPL 条款：需要提供对应源码或指向上游的获取方式）。
- 本项目为个人学习用途，不提供任何内容服务；所有番剧、弹幕数据均来自第三方公开接口，
  与项目作者无关。
