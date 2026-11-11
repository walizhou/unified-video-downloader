# 发布检查（维护者）

## 必须完成

- [ ] 从 Windows 电脑取回 `UnifiedDownloader.cs` 和 `.csproj`，保存到仓库，检查并移除任何 Cookie、账户信息、绝对个人路径。
- [ ] 在 Windows 版调用 yt-dlp 时显式指定随包 `ffmpeg.exe` 的位置；随包包含 `ffprobe.exe`，并在 Windows 10/11 x64 上重测 B站和小红书，确认生成单个含音视频文件。
- [x] 在 Mac 上补测小红书公开单视频链接，确认视频和音频可解码。
- [ ] 复核窗口内的取消、重试、打开文件与打开文件夹。
- [x] 项目源码采用 GPL-3.0-or-later，加入 `LICENSE`；保留第三方许可证、来源、版本与校验信息。
- [ ] 检查发布 ZIP：不含 Cookie、DouK `Volume/`、用户下载记录、日志和视频文件。
- [ ] 使用干净的新用户账号分别测试 Mac、Windows 首次安装和抖音四步引导。
- [ ] Mac 使用 Developer ID 签名、Apple 公证并 stapling；从网络下载的 ZIP 实际测试 Gatekeeper 首次启动。
- [ ] Windows 签名并测试 SmartScreen 初次运行体验，或在发布页如实说明未签名限制。
- [ ] 为两个发布包分别生成 SHA-256；在 GitHub Release 页面列出版本、支持系统、已测平台和已知问题。

## 发布后

- [ ] 保留旧版本 Release，修复问题时发布新版本，不覆盖已经公开的二进制。
- [ ] 升级 DouK、yt-dlp 或 FFmpeg 时重新核对上游发布文件与许可证，并回归测试三个平台。
