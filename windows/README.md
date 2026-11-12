# Windows 版（源码已收录，发行包待实测）

`UnifiedDownloader.cs` 是 C# WinForms 界面源码，采用 GPL-3.0-or-later。原 Windows 版此前在用户电脑上完成过抖音、B站、小红书下载测试；本次补齐了 FFmpeg 调用、链接域名检查和部分错误处理，但**修改后的 Windows EXE 尚未在 Windows 上编译或实测**。请勿把旧 EXE 当作本次修改后的成品。

## 维护者打包

在 Windows 10/11 x64 上打开 PowerShell，进入仓库目录，运行 `powershell -ExecutionPolicy Bypass -File scripts/build-windows.ps1`。脚本使用系统 .NET Framework `csc.exe` 编译源文件，自动从官方发布页下载并校验 DouK 5.8、yt-dlp 与 FFmpeg，然后生成 `dist/VideoDownloader-Windows-x64.zip`。普通用户只需从 GitHub Releases 下载打包好的 ZIP，不需要运行脚本或安装环境。

发布前必须在 Windows 上重新验证三个平台、取消、重试、打开文件/文件夹，以及音视频合并；检查 ZIP 不含 Cookie、DouK `Volume/`、个人下载记录和视频。源码本身不含用户 Cookie。
