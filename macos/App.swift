// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Foundation
import UniformTypeIdentifiers

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 620), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    let link = NSTextField(frame: NSRect(x: 35, y: 395, width: 625, height: 32))
    let folder = NSTextField(frame: NSRect(x: 35, y: 323, width: 625, height: 32))
    let status = NSTextField(labelWithString: "就绪")
    let cookieStatus = NSTextField(labelWithString: "抖音登录文件：尚未导入")
    let progress = NSProgressIndicator(frame: NSRect(x: 35, y: 145, width: 750, height: 12))
    let log = NSTextView(frame: NSRect(x: 36, y: 20, width: 746, height: 118))
    var openFolderButton: NSButton?
    var openFileButton: NSButton?
    var setupWindow: NSWindow?
    var setupStatus: NSTextField?
    var process: Process?
    var lastURL: String?
    var lastFile: URL?
    var before: [String: Int64] = [:]
    var wasCancelled = false
    var taskOutput = ""
    var cookieFile: URL?
    let savedFolderKey = "selectedSaveFolder"
    let lastFileKey = "lastDownloadedVideo"
    let appData = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/UnifiedVideoDownloader")
    var doukSettings: URL { appData.appendingPathComponent("douk/Volume/settings.json") }
    var vendor: URL { Bundle.main.resourceURL!.appendingPathComponent("douk") }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    @discardableResult func button(_ title: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ action: Selector, in view: NSView? = nil) -> NSButton {
        let b = NSButton(title: title, target: self, action: action); b.frame = NSRect(x: x, y: y, width: width, height: 32); b.bezelStyle = .rounded; (view ?? window.contentView!).addSubview(b); return b
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.title = "视频下载器"; window.center(); window.makeKeyAndOrderFront(nil)
        let content = window.contentView!
        content.wantsLayer = true; content.layer?.backgroundColor = NSColor(calibratedWhite: 0.965, alpha: 1).cgColor
        let header = NSView(frame: NSRect(x: 0, y: 490, width: 820, height: 130)); header.wantsLayer = true; header.layer?.backgroundColor = NSColor(calibratedRed: 0.075, green: 0.12, blue: 0.25, alpha: 1).cgColor; content.addSubview(header)
        let icon = NSImageView(frame: NSRect(x: 35, y: 29, width: 72, height: 72)); icon.image = NSImage(contentsOf: Bundle.main.resourceURL!.appendingPathComponent("AppIcon.icns")); header.addSubview(icon)
        let title = NSTextField(labelWithString: "视频下载器"); title.font = NSFont.boldSystemFont(ofSize: 27); title.textColor = .white; title.frame = NSRect(x: 120, y: 72, width: 640, height: 34); header.addSubview(title)
        let subtitle = NSTextField(labelWithString: "一个窗口下载抖音、小红书和 B站视频"); subtitle.font = NSFont.systemFont(ofSize: 13); subtitle.textColor = NSColor(calibratedRed: 0.75, green: 0.84, blue: 0.95, alpha: 1); subtitle.frame = NSRect(x: 120, y: 48, width: 640, height: 22); header.addSubview(subtitle)
        let hint = NSTextField(labelWithString: "粘贴链接 · 选择位置 · 开始下载"); hint.font = NSFont.systemFont(ofSize: 11); hint.textColor = NSColor(calibratedRed: 0.55, green: 0.82, blue: 1, alpha: 1); hint.frame = NSRect(x: 120, y: 28, width: 640, height: 18); header.addSubview(hint)
        let card = NSView(frame: NSRect(x: 20, y: 230, width: 780, height: 242)); card.wantsLayer = true; card.layer?.backgroundColor = NSColor.white.cgColor; card.layer?.cornerRadius = 10; content.addSubview(card)
        let label1 = NSTextField(labelWithString: "视频链接"); label1.font = NSFont.boldSystemFont(ofSize: 13); label1.frame = NSRect(x:35,y:436,width:650,height:20); content.addSubview(label1)
        link.placeholderString = "粘贴抖音、小红书或 B站视频链接"; content.addSubview(link)
        button("粘贴链接", 672, 395, 112, #selector(pasteLink))
        let label2 = NSTextField(labelWithString: "保存位置"); label2.font = NSFont.boldSystemFont(ofSize: 13); label2.frame = NSRect(x:35,y:364,width:650,height:20); content.addSubview(label2)
        let defaultFolder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
        let remembered = UserDefaults.standard.string(forKey: savedFolderKey) ?? previousDouKSaveFolder() ?? defaultFolder
        var rememberedIsDirectory: ObjCBool = false
        folder.stringValue = FileManager.default.fileExists(atPath: remembered, isDirectory: &rememberedIsDirectory) && rememberedIsDirectory.boolValue ? remembered : defaultFolder
        folder.delegate = self; content.addSubview(folder)
        button("选择文件夹", 672, 323, 112, #selector(chooseFolder))
        cookieStatus.font = NSFont.systemFont(ofSize: 12); cookieStatus.textColor = .secondaryLabelColor; cookieStatus.frame = NSRect(x:35,y:275,width:565,height:22); content.addSubview(cookieStatus)
        button("抖音首次设置", 635, 268, 149, #selector(douyinSetup))
        let primary = button("开始下载", 25, 183, 126, #selector(start)); primary.keyEquivalent = "\r"
        button("取消", 160, 183, 91, #selector(cancel)); button("重试", 260, 183, 91, #selector(retry))
        openFolderButton = button("打开文件夹", 360, 183, 112, #selector(openFolder)); openFileButton = button("打开文件", 481, 183, 101, #selector(openFile)); button("使用指南", 591, 183, 101, #selector(openGuide))
        status.frame = NSRect(x:35,y:158,width:750,height:22); status.font = NSFont.systemFont(ofSize: 12); content.addSubview(status)
        progress.isIndeterminate = false; progress.minValue = 0; progress.maxValue = 100; content.addSubview(progress)
        let scroll = NSScrollView(frame: NSRect(x: 25, y: 15, width: 770, height: 126)); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder; log.isEditable = false; log.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular); scroll.documentView = log; content.addSubview(scroll)
        try? FileManager.default.createDirectory(at: appData, withIntermediateDirectories: true)
        chmod(appData.path, 0o700)
        let saved = appData.appendingPathComponent("cookie-source.txt")
        if validCookie(saved) { cookieFile = saved; cookieStatus.stringValue = "已找到抖音登录文件 · 过期时可重新设置" }
        if let path = UserDefaults.standard.string(forKey: lastFileKey), FileManager.default.fileExists(atPath: path) { lastFile = URL(fileURLWithPath: path) }
        else { lastFile = mostRecentVideo(in: URL(fileURLWithPath: folder.stringValue, isDirectory: true)) }
        rememberFolder()
        clearDouKCookie()
        if ProcessInfo.processInfo.arguments.contains("--self-test-core") {
            let sample = URL(string: "https://www.douyin.com/jingxuan?modal_id=7705027809474809122")!
            let profile = URL(string: "https://www.douyin.com/user/self?from_tab_name=main&modal_id=7705027809474809122")!
            let expected = "https://www.douyin.com/video/7705027809474809122"
            let passed = normalizedDouyinURL(sample) == expected && normalizedDouyinURL(profile) == expected
            fputs(passed ? "PASS: Douyin modal_id links normalized\n" : "FAIL: Douyin URL normalization\n", stderr)
            Darwin.exit(passed ? 0 : 1)
        }
        if let flag = ProcessInfo.processInfo.arguments.firstIndex(of: "--self-test-buttons"), ProcessInfo.processInfo.arguments.count > flag + 1 {
            let testFolder = ProcessInfo.processInfo.arguments[flag + 1]
            let previousFolder = UserDefaults.standard.string(forKey: savedFolderKey)
            let previousFile = UserDefaults.standard.string(forKey: lastFileKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.folder.stringValue = testFolder
                self.lastFile = nil
                self.openFolderButton?.performClick(nil)
                self.openFileButton?.performClick(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let passed = UserDefaults.standard.string(forKey: self.savedFolderKey) == testFolder && self.lastFile?.deletingLastPathComponent().path == testFolder && self.log.string.contains("已打开保存文件夹") && self.log.string.contains("正在打开")
                    if let previousFolder { UserDefaults.standard.set(previousFolder, forKey: self.savedFolderKey) } else { UserDefaults.standard.removeObject(forKey: self.savedFolderKey) }
                    if let previousFile { UserDefaults.standard.set(previousFile, forKey: self.lastFileKey) } else { UserDefaults.standard.removeObject(forKey: self.lastFileKey) }
                    fputs(passed ? "PASS: folder and file buttons opened selected locations\n" : "FAIL: folder or file button did not work\n", stderr)
                    Darwin.exit(passed ? 0 : 1)
                }
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--self-test-close") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.setupWindow?.standardWindowButton(.closeButton)?.performClick(nil) }
                self.douyinSetup()
                let passed = self.window.isVisible && self.setupWindow == nil
                fputs(passed ? "PASS: setup close button left main window visible\n" : "FAIL: main window closed with setup\n", stderr)
                Darwin.exit(passed ? 0 : 1)
            }
        }
    }
    func say(_ s: String) { DispatchQueue.main.async { self.status.stringValue = s; self.log.string = (self.log.string + "\n" + s).suffix(7000).description } }
    @objc func pasteLink() { link.stringValue = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    @objc func openGuide() { NSWorkspace.shared.open(Bundle.main.resourceURL!.appendingPathComponent("使用指南.txt")) }
    func controlTextDidEndEditing(_ obj: Notification) { if obj.object as? NSTextField === folder { rememberFolder() } }
    func previousDouKSaveFolder() -> String? {
        guard let data = try? Data(contentsOf: doukSettings), let config = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let root = config["root"] as? String, let name = config["folder_name"] as? String, !root.isEmpty, !name.isEmpty else { return nil }
        let path = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent(name, isDirectory: true).path
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue ? path : nil
    }
    func rememberFolder() { var isDirectory: ObjCBool = false; let path = folder.stringValue; if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue { UserDefaults.standard.set(path, forKey: savedFolderKey) } }
    @objc func chooseFolder() { let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.directoryURL = URL(fileURLWithPath: folder.stringValue); if p.runModal() == .OK, let u = p.url { folder.stringValue = u.path; rememberFolder(); say("保存位置：\(u.path)") } }
    @objc func douyinSetup() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 610, height: 320), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "抖音首次设置"; w.center(); w.delegate = self; w.isReleasedWhenClosed = false; setupWindow = w
        let view = w.contentView!; view.wantsLayer = true; view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let intro = NSTextField(wrappingLabelWithString: "只需设置一次：在 Chrome 登录抖音，用浏览器扩展将当前网站的 Cookie 导出为 Netscape 格式 cookies.txt，然后让下载器查找文件。")
        intro.frame = NSRect(x: 28, y: 247, width: 554, height: 48); intro.font = NSFont.systemFont(ofSize: 13); view.addSubview(intro)
        button("1  打开抖音", 28, 181, 165, #selector(openDouyin), in: view)
        button("2  获取导出扩展", 222, 181, 165, #selector(openExtension), in: view)
        button("3  自动查找文件", 416, 181, 165, #selector(autoFindCookie), in: view)
        button("4  手动选择 cookies.txt", 28, 119, 222, #selector(manualImportCookie), in: view)
        let state = NSTextField(labelWithString: cookieFile == nil ? "尚未导入抖音登录文件" : "已找到抖音登录文件，可直接下载")
        state.frame = NSRect(x: 28, y: 74, width: 550, height: 24); state.font = NSFont.systemFont(ofSize: 12); state.textColor = .secondaryLabelColor; view.addSubview(state); setupStatus = state
        let warning = NSTextField(wrappingLabelWithString: "Cookie 相当于账号凭证。只在自己的电脑上导入，不要发给别人；无需手动放进应用文件夹。")
        warning.frame = NSRect(x: 28, y: 22, width: 550, height: 38); warning.font = NSFont.systemFont(ofSize: 11); warning.textColor = .systemRed; view.addSubview(warning)
        NSApp.runModal(for: w); w.orderOut(nil); setupWindow = nil; setupStatus = nil
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === setupWindow else { return true }
        NSApp.stopModal()
        sender.orderOut(nil)
        return false
    }
    @objc func openDouyin() { NSWorkspace.shared.open(URL(string: "https://www.douyin.com")!) }
    @objc func openExtension() { NSWorkspace.shared.open(URL(string: "https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc")!) }
    @objc func autoFindCookie() { findCookie() }
    @objc func manualImportCookie() { chooseCookie() }
    func findCookie() {
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let files = (try? FileManager.default.contentsOfDirectory(at: downloads, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let candidates = files.filter { $0.pathExtension.lowercased() == "txt" && $0.lastPathComponent.lowercased().contains("cookies") }
        let sorted = candidates.sorted { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) ?? .distantPast > (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) ?? .distantPast }
        if let u = sorted.first(where: validCookie) { importCookie(u) } else { setupStatus?.stringValue = "未找到有效文件，请点第 4 步手动选择"; say("未找到有效的抖音 cookies.txt；请手动选择") }
    }
    @objc func chooseCookie() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.plainText]; p.message = "选择从 Chrome 导出的 Netscape 格式 cookies.txt"; if p.runModal() == .OK, let u = p.url { importCookie(u) }
    }
    func validCookie(_ u: URL) -> Bool {
        guard let data = try? String(contentsOf: u), data.contains("# Netscape HTTP Cookie File") else { return false }
        return data.split(separator: "\n").contains { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            return fields.count >= 7 && fields[0].contains("douyin.com")
        }
    }
    func importCookie(_ u: URL) {
        guard validCookie(u), let data = try? String(contentsOf: u) else { say("未识别到 Netscape 格式的抖音 Cookie，请重新导出"); return }
        let saved = appData.appendingPathComponent("cookie-source.txt")
        do { try data.write(to: saved, atomically: true, encoding: .utf8); chmod(saved.path, 0o600); cookieFile = saved; cookieStatus.stringValue = "已找到抖音登录文件 · 过期时可重新设置"; setupStatus?.stringValue = "已找到抖音登录文件，可直接下载"; say("抖音 Cookie 已导入，可直接下载；原文件无需移动") }
        catch { say("导入 Cookie 失败：\(error.localizedDescription)") }
    }
    func chmod(_ path: String, _ mode: mode_t) { _ = Darwin.chmod(path, mode) }
    @objc func start() { run(link.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) }
    @objc func retry() { if let u = lastURL { run(u) } else { say("本次打开应用后尚无可重试的下载任务") } }
    @objc func cancel() { if let p = process, p.isRunning { wasCancelled = true; p.terminate(); say("正在取消…") } }
    @objc func openFile() {
        let destination = URL(fileURLWithPath: folder.stringValue, isDirectory: true)
        let file = (lastFile.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }) ?? mostRecentVideo(in: destination)
        guard let file else { say("尚未找到可打开的视频文件；请先下载，或检查保存位置") ; return }
        if NSWorkspace.shared.open(file) { lastFile = file; UserDefaults.standard.set(file.path, forKey: lastFileKey); say("正在打开：\(file.lastPathComponent)") }
        else { say("无法打开该视频文件：\(file.lastPathComponent)") }
    }
    @objc func openFolder() {
        let url = URL(fileURLWithPath: folder.stringValue, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { say("保存文件夹不存在，请重新选择") ; return }
        rememberFolder()
        if NSWorkspace.shared.open(url) { say("已打开保存文件夹：\(url.path)") } else { say("无法打开保存文件夹：\(url.path)") }
    }
    func normalizedDouyinURL(_ url: URL) -> String {
        if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "modal_id" })?.value,
           !id.isEmpty, id.allSatisfy({ $0.isNumber }) { return "https://www.douyin.com/video/\(id)" }
        return url.absoluteString
    }
    func videoFiles(in folder: URL) -> [String: Int64] {
        let extensions: Set<String> = ["mp4", "webm", "mkv", "mov", "m4v"]
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])) ?? []
        var result: [String: Int64] = [:]
        for file in files where extensions.contains(file.pathExtension.lowercased()) {
            let info = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if info?.isRegularFile == true { result[file.lastPathComponent] = Int64(info?.fileSize ?? 0) }
        }
        return result
    }
    func mostRecentVideo(in folder: URL) -> URL? {
        let extensions: Set<String> = ["mp4", "webm", "mkv", "mov", "m4v"]
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey])) ?? []
        return files.filter { extensions.contains($0.pathExtension.lowercased()) && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .max { a, b in
                let left = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let right = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return left < right
            }
    }
    func clearDouKCookie() {
        guard let data = try? Data(contentsOf: doukSettings), var config = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], !(config["cookie"] as? String ?? "").isEmpty else { return }
        config["cookie"] = ""
        if let cleaned = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]) { try? cleaned.write(to: doukSettings, options: .atomic); chmod(doukSettings.path, 0o600) }
    }
    func run(_ raw: String) {
        guard process == nil else { say("已有下载任务正在运行"); return }
        guard let url = URL(string: raw), let host = url.host?.lowercased(), ["http","https"].contains(url.scheme ?? "") else { say("请输入有效的视频链接"); return }
        let isDouyin = host == "douyin.com" || host.hasSuffix(".douyin.com") || host == "iesdouyin.com"
        let isXhs = host == "xiaohongshu.com" || host.hasSuffix(".xiaohongshu.com") || host == "xhslink.com"
        let isBili = host == "bilibili.com" || host.hasSuffix(".bilibili.com") || host == "b23.tv"
        guard isDouyin || isXhs || isBili else { say("目前只支持抖音、小红书和 B站链接"); return }
        let dest = URL(fileURLWithPath: folder.stringValue, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dest.path, isDirectory: &isDirectory), isDirectory.boolValue else { say("保存文件夹不存在"); return }
        guard FileManager.default.isWritableFile(atPath: dest.path) else { say("保存文件夹不可写，请重新选择"); return }
        rememberFolder()
        if isDouyin && cookieFile == nil { say("首次下载抖音，请先完成 Cookie 导入"); douyinSetup(); if cookieFile == nil { return } }
        lastURL = raw; lastFile = nil; wasCancelled = false; taskOutput = ""; log.string = ""; progress.doubleValue = 0; before = videoFiles(in: dest)
        let cookieValue = isDouyin ? cookieHeader() : ""
        let cookieSecrets = cookieValue.components(separatedBy: "; ").compactMap { pair -> String? in
            guard let equal = pair.firstIndex(of: "=") else { return nil }
            let value = String(pair[pair.index(after: equal)...]); return value.count >= 8 ? value : nil
        }
        let p = Process(); let output = Pipe(); p.standardOutput = output; p.standardError = output
        if isDouyin {
            let downloadURL = normalizedDouyinURL(url)
            let executable = appData.appendingPathComponent("douk/DouK-Downloader")
            if !FileManager.default.fileExists(atPath: executable.path) { try? FileManager.default.copyItem(at: vendor, to: appData.appendingPathComponent("douk")) }
            let volume = appData.appendingPathComponent("douk/Volume"); try? FileManager.default.createDirectory(at: volume, withIntermediateDirectories: true)
            let firstRun = !FileManager.default.fileExists(atPath: volume.appendingPathComponent("DouK-Downloader.db").path)
            if firstRun {
                let alert = NSAlert(); alert.messageText = "首次使用 DouK-Downloader"; alert.informativeText = "DouK 将显示官方免责声明。请先阅读其项目 README 中的免责声明；同意后应用会完成首次语言与声明步骤。"; alert.addButton(withTitle: "我已阅读并同意"); alert.addButton(withTitle: "取消")
                if alert.runModal() != .alertFirstButtonReturn { say("已取消 DouK 首次设置"); return }
            }
            let settings = doukSettings
            var config: [String: Any] = [:]
            if let data = try? Data(contentsOf: settings), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { config = obj }
            config["root"] = dest.deletingLastPathComponent().path; config["folder_name"] = dest.lastPathComponent; config["folder_mode"] = false; config["run_command"] = "5 2 1 Q"; config["cookie"] = cookieValue
            guard let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]), (try? data.write(to: settings, options: .atomic)) != nil else { say("无法准备 DouK 配置文件"); return }
            chmod(settings.path, 0o600)
            p.executableURL = executable; p.currentDirectoryURL = executable.deletingLastPathComponent(); let input = Pipe(); p.standardInput = input
            do { try p.run() } catch { clearDouKCookie(); say("启动 DouK 失败：\(error.localizedDescription)"); return }; process = p; input.fileHandleForWriting.write(((firstRun ? "1\nYES\n" : "") + downloadURL + "\n\n").data(using: .utf8)!); try? input.fileHandleForWriting.close(); progress.isIndeterminate = true; progress.startAnimation(nil); say("抖音：正在处理（该工具不提供可靠百分比）")
        } else {
            p.executableURL = Bundle.main.resourceURL!.appendingPathComponent("yt-dlp_macos")
            let ffmpeg = Bundle.main.resourceURL!.appendingPathComponent("ffmpeg")
            guard FileManager.default.isExecutableFile(atPath: ffmpeg.path) else { say("缺少 FFmpeg，无法保证音视频合并"); return }
            p.arguments = ["--newline", "--no-playlist", "--progress", "--no-mtime", "--ffmpeg-location", ffmpeg.path, "-P", dest.path, "-o", "%(title).180B [%(id)s].%(ext)s", raw]
            do { try p.run() } catch { say("启动 yt-dlp 失败：\(error.localizedDescription)"); return }; process = p; progress.isIndeterminate = false; say("正在下载…")
        }
        output.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData; if data.isEmpty { return }; var s = String(decoding: data, as: UTF8.self)
            if isDouyin { for secret in cookieSecrets { s = s.replacingOccurrences(of: secret, with: "[Cookie 已隐藏]") } }
            DispatchQueue.main.async { guard let self = self else { return }; self.taskOutput = (self.taskOutput + s).suffix(20000).description; self.log.string = (self.log.string + s).suffix(7000).description
                if !isDouyin, let range = s.range(of: #"\[download\]\s+([0-9]+(?:\.[0-9]+)?)%"#, options: .regularExpression) {
                    let value = s[range].replacingOccurrences(of: "[download]", with: "").replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                    if let n = Double(value) { self.progress.doubleValue = n; self.status.stringValue = String(format: "下载中 %.1f%%", n) }
                }
            }
        }
        p.terminationHandler = { [weak self] task in DispatchQueue.main.async { guard let self = self else { return }; output.fileHandleForReading.readabilityHandler = nil; self.process = nil
            if isDouyin { self.clearDouKCookie(); self.progress.stopAnimation(nil); self.progress.isIndeterminate = false }
            let after = self.videoFiles(in: dest)
            let changed = after.filter { name, size in size > 0 && self.before[name] != size }.keys.sorted()
            self.lastFile = changed.first.map { dest.appendingPathComponent($0) }
            let outputText = self.taskOutput.lowercased()
            if self.wasCancelled { self.say("已取消；如有未完成的临时文件，可在保存文件夹中清理") }
            else if outputText.contains("formats won't be merged") || outputText.contains("ffmpeg is not installed") { self.lastFile = nil; self.say("音视频未合并，请检查 FFmpeg") }
            else if let file = self.lastFile, task.terminationStatus == 0, file.lastPathComponent.range(of: #"\.f[0-9]+\."#, options: .regularExpression) == nil { self.progress.doubleValue = 100; UserDefaults.standard.set(file.path, forKey: self.lastFileKey); self.say("下载完成：\(file.lastPathComponent)") }
            else if isDouyin && (outputText.contains("跳过") || outputText.contains("已下载")) { self.say("该作品可能已下载过；请检查保存文件夹") }
            else if outputText.contains("ffmpeg") { self.say("下载未完成：可能缺少 FFmpeg，详见下方日志") }
            else if outputText.contains("403") || outputText.contains("cookie") && outputText.contains("失效") { self.say("访问被拒绝；请重新导出抖音 Cookie 后重试") }
            else if outputText.contains("timed out") || outputText.contains("超时") { self.say("网络请求超时，请稍后重试") }
            else { self.say("下载未完成；请查看下方日志并重试") }
        } }
    }
    func cookieHeader() -> String {
        guard let file = cookieFile, let s = try? String(contentsOf: file) else { return "" }
        return s.split(separator: "\n").compactMap { line -> String? in let f = line.split(separator: "\t", omittingEmptySubsequences: false); return f.count >= 7 && (f[0].contains("douyin.com") || f[0].contains("iesdouyin.com")) ? "\(f[5])=\(f[6])" : nil }.joined(separator: "; ")
    }
}
let app = NSApplication.shared
let delegate = App(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
