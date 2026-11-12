# 普通用户安装与首次使用

## Mac（Apple 芯片）

1. 从 GitHub **Releases** 下载 `VideoDownloader-macOS-AppleSilicon.zip`，解压。
2. 将 `统一视频下载器.app` 拖入 Finder 的“应用程序”。从“应用程序”或启动台打开。
3. 粘贴单个视频链接，点“选择文件夹”设置保存位置，再点“开始下载”。应用会记住该文件夹。下载完成后可点“打开文件”或“打开文件夹”。

当前测试版尚未获得 Apple Developer ID 签名与公证，macOS 可能拦截首次打开。请只从本仓库 Releases 下载，并核对发布页 SHA-256。若系统提示无法验证应用：先尝试打开一次，然后进入“系统设置 → 隐私与安全性”，在底部点击“仍要打开”，再次确认。Apple 官方步骤：https://support.apple.com/zh-cn/102445 。无需关闭系统安全保护。后续会提供 Developer ID 公证版。

## Windows 10/11 x64

1. 从 GitHub **Releases** 下载 `VideoDownloader-Windows-x64.zip`。
2. 右键 ZIP 选择“全部解压”。不要在 ZIP 预览窗口中运行，也不要只复制 EXE。
3. 双击解压文件夹内的 `VideoDownloader.exe`。粘贴链接、选保存文件夹、点“开始下载”。

正式 Windows 包应把 `yt-dlp.exe`、`DouK/`、`ffmpeg.exe` 与 `ffprobe.exe` 等所需文件一起打包，并在 Windows 10/11 实测音视频合并。旧 Windows 包缺 FFmpeg。修订后的源码和构建脚本已准备好，待 Windows 实机编译与测试后再发布安装包。

## 抖音首次设置（两个系统相同）

点击主界面的“抖音首次设置”：

1. **打开抖音**：在 Chrome 登录自己的账号。
2. **获取导出扩展**：直达 Chrome 网上应用店的 Get cookies.txt LOCALLY；由用户自行决定是否安装。回到已登录的抖音网页，导出当前网站的 Netscape 格式 `cookies.txt`。
3. **自动查找文件**：应用检查“下载”文件夹，找到有效文件后自动导入。
4. **手动选择 cookies.txt**：自动查找失败时，选择刚导出的 `.txt` 文件。

无需把 Cookie 手动放到程序目录。Cookie 是登录凭证，不要上传到 GitHub、发给他人或放进分享包。过期时重新导出并导入。

## 常见问题

- **没有声音或出现两个文件**：缺 FFmpeg 或 FFmpeg 合并失败。正式发布包应自带 FFmpeg；请在项目 Issues 提供日志，但不要贴 Cookie。
- **抖音提示 403 或访问被拒绝**：先确认浏览器中的视频能打开，再重新导出 Cookie。
- **下载按钮没有生成视频**：确认链接是单个公开视频、保存文件夹存在且可写；查看窗口下方日志。
- **找不到保存位置**：点击“打开文件夹”。它打开当前显示的保存文件夹；该位置下次启动会保留。
