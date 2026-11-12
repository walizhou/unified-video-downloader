# 视频下载器 / Unified Video Downloader

一个窗口下载抖音、小红书和 B站视频。Mac 与 Windows 使用相近的界面和四步抖音首次设置，各平台分别打包运行组件；用户无需安装 Python 或运行命令行。

> 发布状态：Mac 版已在 Apple 芯片 Mac 上实测抖音、小红书和 B站，作为测试版提供。Windows 源码已收录并补上 FFmpeg 调用，但修订后的 EXE 尚未在 Windows 上编译和实测，因此暂不发布 Windows 包。Mac 包目前仅做临时签名，未使用 Developer ID 公证；其他 Mac 的首次打开可能被系统拦截。

## 普通用户从哪里下载

请到仓库右侧的 **Releases** 下载对应文件。Windows 版在完成源码整理与测试后另行发布：

| 系统 | 下载文件 | 使用方法 |
| --- | --- | --- |
| Apple 芯片 Mac（macOS 13+） | `VideoDownloader-macOS-AppleSilicon.zip` | 解压后把 `.app` 放进“应用程序”，双击打开。 |
| Windows 10/11 x64 | `VideoDownloader-Windows-x64.zip` | 完整解压，再双击文件夹中的 `视频下载器.exe`。不要只复制 EXE。 |

不要使用 GitHub 绿色 **Code → Download ZIP** 当作安装包；那是源码。下载器应随包包含 DouK、yt-dlp，以及用于合并音视频的 FFmpeg。抖音 Cookie 由每位用户在自己电脑上导出并在应用的“抖音首次设置”中导入，发布包不包含 Cookie。

详细步骤见 [普通用户安装与首次使用](docs/INSTALL.md)。

## 开发者

- Mac 界面源码：[`macos/App.swift`](macos/App.swift)（AppKit）。
- Windows 界面源码：[`windows/UnifiedDownloader.cs`](windows/UnifiedDownloader.cs)（WinForms）；[Windows 打包说明](windows/README.md)。维护者可在 Windows 上双击 `在Windows上打包.bat`。
- 第三方组件及版本：[THIRD_PARTY.txt](docs/THIRD_PARTY.txt)。
- 发布前检查：[RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)。

本项目自有源码采用 [GPL-3.0-or-later](LICENSE)。内置组件各自遵守其许可证；当前包内 FFmpeg 构建启用了 GPLv3。

请只下载和保存你有权使用的内容，并遵守网站规则。
