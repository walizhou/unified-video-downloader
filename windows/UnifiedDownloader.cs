// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Windows.Forms;

class UnifiedDownloader : Form {
    TextBox url = new TextBox(), folder = new TextBox(), cookies = new TextBox(), log = new TextBox();
    Button start = new Button(), cancel = new Button(), retry = new Button(), openFile = new Button();
    Label status = new Label(), cookieStatus = new Label();
    ProgressBar activity = new ProgressBar();
    Process activeProcess;
    string activeFolder, lastFile, lastError;
    bool canceled, activeDouyin, sawSkip;
    HashSet<string> cookieSecrets = new HashSet<string>();
    Dictionary<string,long> filesBefore = new Dictionary<string,long>(StringComparer.OrdinalIgnoreCase);
    string basePath = AppDomain.CurrentDomain.BaseDirectory;
    string prefsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "UnifiedVideoDownloader", "settings.json");
    JavaScriptSerializer json = new JavaScriptSerializer();
    public UnifiedDownloader() {
        Text = "视频下载器"; Size = new Size(820, 730); MinimumSize = Size;
        StartPosition = FormStartPosition.CenterScreen; Font = new Font("Microsoft YaHei UI", 10);
        BackColor=Color.FromArgb(245,247,251);
        try{string iconPath=Path.Combine(basePath,"app-icon.ico");if(File.Exists(iconPath))Icon=new Icon(iconPath);}catch{}
        var header=new Panel{BackColor=Color.FromArgb(20,30,63),Location=new Point(0,0),Size=new Size(ClientSize.Width,140),Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right};Controls.Add(header);
        var appIcon=new PictureBox{Location=new Point(28,25),Size=new Size(76,76),SizeMode=PictureBoxSizeMode.Zoom,BackColor=header.BackColor};
        try{string imagePath=Path.Combine(basePath,"app-icon.png");if(File.Exists(imagePath)){using(var img=Image.FromFile(imagePath))appIcon.Image=new Bitmap(img);}}catch{}header.Controls.Add(appIcon);
        header.Controls.Add(new Label{Text="视频下载器",ForeColor=Color.White,Font=new Font("Microsoft YaHei UI",21,FontStyle.Bold),Location=new Point(115,24),AutoSize=true});
        header.Controls.Add(new Label{Text="一个窗口下载抖音、小红书和 B站视频",ForeColor=Color.FromArgb(204,216,244),Font=new Font("Microsoft YaHei UI",10),Location=new Point(117,77),AutoSize=true});
        header.Controls.Add(new Label{Text="粘贴链接  ·  选择位置  ·  开始下载",ForeColor=Color.FromArgb(136,213,236),Font=new Font("Microsoft YaHei UI",9),Location=new Point(117,105),AutoSize=true});

        var card=new Panel{BackColor=Color.White,Location=new Point(22,160),Size=new Size(ClientSize.Width-44,255),Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right};Controls.Add(card);
        card.Controls.Add(new Label{Text="视频链接",Location=new Point(22,17),AutoSize=true,ForeColor=Color.FromArgb(35,49,74),Font=new Font("Microsoft YaHei UI",10,FontStyle.Bold)});
        url.SetBounds(22,45,card.Width-155,35);url.Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right;url.BorderStyle=BorderStyle.FixedSingle;card.Controls.Add(url);
        var paste=StyledButton("粘贴链接",Color.FromArgb(235,242,252),Color.FromArgb(25,72,132));paste.SetBounds(card.Width-123,45,100,35);paste.Anchor=AnchorStyles.Top|AnchorStyles.Right;
        paste.Click+=(s,e)=>{if(Clipboard.ContainsText())url.Text=Clipboard.GetText().Trim();};card.Controls.Add(paste);
        card.Controls.Add(new Label{Text="保存位置",Location=new Point(22,96),AutoSize=true,ForeColor=Color.FromArgb(35,49,74),Font=new Font("Microsoft YaHei UI",10,FontStyle.Bold)});
        folder.SetBounds(22,125,card.Width-155,35);folder.Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right;folder.BorderStyle=BorderStyle.FixedSingle;card.Controls.Add(folder);
        var browse=StyledButton("选择文件夹",Color.FromArgb(235,242,252),Color.FromArgb(25,72,132));browse.SetBounds(card.Width-123,125,100,35);browse.Anchor=AnchorStyles.Top|AnchorStyles.Right;
        browse.Click+=(s,e)=>{using(var d=new FolderBrowserDialog())if(d.ShowDialog()==DialogResult.OK)folder.Text=d.SelectedPath;};card.Controls.Add(browse);
        cookieStatus.SetBounds(22,189,card.Width-205,42);cookieStatus.Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right;cookieStatus.ForeColor=Color.FromArgb(83,100,123);cookieStatus.Font=new Font("Microsoft YaHei UI",9);card.Controls.Add(cookieStatus);
        var setup=StyledButton("抖音首次设置",Color.FromArgb(236,248,250),Color.FromArgb(0,112,134));setup.SetBounds(card.Width-173,184,150,38);setup.Anchor=AnchorStyles.Top|AnchorStyles.Right;setup.Click+=(s,e)=>{ConfigureCookie();UpdateCookieStatus();};card.Controls.Add(setup);
        cookies.Visible=false;Controls.Add(cookies);

        start=StyledButton("开始下载",Color.FromArgb(33,116,221),Color.White);start.Font=new Font("Microsoft YaHei UI",11,FontStyle.Bold);start.SetBounds(22,435,146,43);start.Click+=Download;Controls.Add(start);
        cancel=StyledButton("取消",Color.White,Color.FromArgb(164,50,50));cancel.SetBounds(180,435,102,43);cancel.Enabled=false;cancel.Click+=(s,e)=>CancelDownload();Controls.Add(cancel);
        retry=StyledButton("重试",Color.White,Color.FromArgb(33,70,117));retry.SetBounds(294,435,94,43);retry.Enabled=false;retry.Click+=Download;Controls.Add(retry);
        var open=StyledButton("打开文件夹",Color.White,Color.FromArgb(33,70,117));open.SetBounds(400,435,129,43);open.Click+=(s,e)=>{if(Directory.Exists(folder.Text))Process.Start("explorer.exe","\""+folder.Text+"\"");};Controls.Add(open);
        openFile=StyledButton("打开文件",Color.White,Color.FromArgb(33,70,117));openFile.SetBounds(541,435,112,43);openFile.Enabled=false;openFile.Click+=(s,e)=>{if(File.Exists(lastFile))Process.Start(lastFile);};Controls.Add(openFile);
        var guide=StyledButton("使用指南",Color.White,Color.FromArgb(33,70,117));guide.SetBounds(665,435,112,43);guide.Click+=(s,e)=>{string p=Path.Combine(basePath,"先看使用指南.txt");if(!File.Exists(p))p=Path.Combine(basePath,"先看使用指南.pdf");if(File.Exists(p))Process.Start(p);else MessageBox.Show("程序文件夹里没有找到使用指南。","提示");};Controls.Add(guide);
        status.SetBounds(22,488,ClientSize.Width-44,23);status.Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right;status.Text="准备就绪 · 粘贴视频链接即可开始";status.ForeColor=Color.FromArgb(55,75,103);status.Font=new Font("Microsoft YaHei UI",9);Controls.Add(status);
        activity.SetBounds(22,514,ClientSize.Width-44,5);activity.Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right;activity.Style=ProgressBarStyle.Continuous;activity.MarqueeAnimationSpeed=25;Controls.Add(activity);
        log.Multiline=true;log.ReadOnly=true;log.ScrollBars=ScrollBars.Vertical;log.BackColor=Color.White;log.BorderStyle=BorderStyle.FixedSingle;log.Font=new Font("Consolas",9);log.SetBounds(22,530,ClientSize.Width-44,ClientSize.Height-550);log.Anchor=AnchorStyles.Top|AnchorStyles.Bottom|AnchorStyles.Left|AnchorStyles.Right;log.Text="下载进度和提示会显示在这里。";Controls.Add(log);
        folder.Text=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"Downloads");
        try { if(File.Exists(prefsPath)){var p=json.Deserialize<Dictionary<string,string>>(File.ReadAllText(prefsPath));if(p.ContainsKey("folder"))folder.Text=p["folder"];if(p.ContainsKey("cookies"))cookies.Text=p["cookies"];}} catch {}
        ClearDouKCookie(); // 清除上次异常退出时可能留在配置中的 Cookie
        if(!ValidCookieFile(cookies.Text))cookies.Text=FindCookieFile()??"";
        UpdateCookieStatus();
    }
    Button StyledButton(string label,Color back,Color fore){var b=new Button{Text=label,BackColor=back,ForeColor=fore,FlatStyle=FlatStyle.Flat,Cursor=Cursors.Hand};b.FlatAppearance.BorderSize=0;return b;}
    void UpdateCookieStatus(){cookieStatus.Text=ValidCookieFile(cookies.Text)?"已找到抖音登录文件 · 过期时可在此重新设置":"抖音首次使用需要设置登录文件 · B站和小红书可直接下载";}
    bool IsDouyinCookieDomain(string domain){
        if(domain.StartsWith("#HttpOnly_"))domain=domain.Substring(10);
        domain=domain.TrimStart('.').ToLowerInvariant();
        return domain=="douyin.com"||domain.EndsWith(".douyin.com");
    }
    bool ValidCookieFile(string path){
        try{if(!File.Exists(path))return false;int n=0;foreach(string line in File.ReadLines(path,Encoding.UTF8)){if(++n>500)break;if((line.StartsWith("#")&&!line.StartsWith("#HttpOnly_"))||line.Trim().Length==0)continue;var f=line.Split(new[]{'\t'},7);if(f.Length==7&&IsDouyinCookieDomain(f[0])&&f[5].Length>0)return true;}}catch{}return false;
    }
    string FindCookieFile(){
        string best=null;DateTime newest=DateTime.MinValue;
        var dirs=new List<string>{Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"Downloads"),Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory)};
        try{dirs.Add(Directory.GetParent(basePath.TrimEnd(Path.DirectorySeparatorChar)).FullName);}catch{}
        foreach(string drive in Environment.GetLogicalDrives()){string moved=Path.Combine(drive,"360MoveData","Users",Environment.UserName,"Desktop");if(Directory.Exists(moved))dirs.Add(moved);}
        foreach(string dir in dirs){
            try{foreach(string path in Directory.GetFiles(dir,"*.txt")){string name=Path.GetFileName(path).ToLowerInvariant();if(!name.Contains("douyin")||!name.Contains("cookie"))continue;var time=File.GetLastWriteTimeUtc(path);if(time>newest&&ValidCookieFile(path)){best=path;newest=time;}}}catch{}
        }return best;
    }
    bool ConfigureCookie(){
        using(var d=new Form()){d.Text="抖音首次设置";d.Size=new Size(580,320);d.StartPosition=FormStartPosition.CenterParent;d.FormBorderStyle=FormBorderStyle.FixedDialog;d.MaximizeBox=false;d.MinimizeBox=false;
            d.Controls.Add(new Label{Text="只需设置一次：先在 Chrome 打开并登录抖音，然后用浏览器扩展\n导出当前网站的 Netscape 格式 cookies.txt。导出后点“自动查找”。",Location=new Point(20,20),Size=new Size(530,60)});
            var site=new Button{Text="1  打开抖音",Location=new Point(20,95),Size=new Size(155,36)};site.Click+=(s,e)=>Process.Start("https://www.douyin.com/");d.Controls.Add(site);
            var ext=new Button{Text="2  获取导出扩展",Location=new Point(190,95),Size=new Size(160,36)};ext.Click+=(s,e)=>Process.Start("https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc");d.Controls.Add(ext);
            var find=new Button{Text="3  自动查找文件",Location=new Point(365,95),Size=new Size(170,36)};find.Click+=(s,e)=>{var path=FindCookieFile();if(path==null)MessageBox.Show(d,"还没有找到抖音登录文件。请先在抖音网页点击扩展，选择 Netscape 格式并导出。","提示");else{cookies.Text=path;UpdateCookieStatus();d.DialogResult=DialogResult.OK;}};d.Controls.Add(find);
            var select=new Button{Text="手动选择 cookies.txt",Location=new Point(20,155),Size=new Size(190,36)};select.Click+=(s,e)=>{using(var file=new OpenFileDialog()){file.Filter="cookies.txt|*.txt|所有文件|*.*";if(file.ShowDialog(d)==DialogResult.OK){if(ValidCookieFile(file.FileName)){cookies.Text=file.FileName;UpdateCookieStatus();d.DialogResult=DialogResult.OK;}else MessageBox.Show(d,"文件不是有效的抖音 cookies.txt，请重新导出 Netscape 格式。","提示");}}};d.Controls.Add(select);
            d.Controls.Add(new Label{Text="登录文件相当于账号凭证，请保存在自己的电脑上，不要发给别人。",Location=new Point(20,215),Size=new Size(530,40),ForeColor=Color.DarkRed});
            return d.ShowDialog(this)==DialogResult.OK;
        }
    }
    Dictionary<string,long> SnapshotFiles(string dir){
        var result=new Dictionary<string,long>(StringComparer.OrdinalIgnoreCase);
        try{foreach(string path in Directory.GetFiles(dir)){if(!VideoFile(path))continue;try{result[path]=new FileInfo(path).Length;}catch{}}}catch{}return result;
    }
    bool VideoFile(string path){string ext=Path.GetExtension(path).ToLowerInvariant();return ext==".mp4"||ext==".webm"||ext==".mkv"||ext==".mov"||ext==".m4v"||ext==".flv"||ext==".avi";}
    string NewFile(){
        string best=null;DateTime newest=DateTime.MinValue;
        try{foreach(string path in Directory.GetFiles(activeFolder)){if(!VideoFile(path))continue;try{var f=new FileInfo(path);long old;if(filesBefore.TryGetValue(path,out old)&&old==f.Length)continue;if(f.LastWriteTimeUtc>newest){best=path;newest=f.LastWriteTimeUtc;}}catch{}}}catch{}return best;
    }
    void Say(string message){
        if(IsDisposed)return;if(InvokeRequired){BeginInvoke(new Action<string>(Say),message);return;}
        foreach(string secret in cookieSecrets)if(secret.Length>=8)message=message.Replace(secret,"[Cookie 已隐藏]");
        log.AppendText(message+Environment.NewLine);
        if(message.StartsWith("ERROR:",StringComparison.OrdinalIgnoreCase)||message.Contains("HTTP Error 403")||message.Contains("下载失败"))lastError=message;
        if(Regex.IsMatch(message,@"跳过视频作品\s*[1-9]"))sawSkip=true;
        if(!start.Enabled){
            var m=Regex.Match(message,@"\[download\]\s*(\d+(?:\.\d+)?)%");
            if(m.Success){double value;if(double.TryParse(m.Groups[1].Value,NumberStyles.Float,CultureInfo.InvariantCulture,out value)){
                activity.Style=ProgressBarStyle.Continuous;activity.Value=Math.Max(0,Math.Min(100,(int)value));
                var speed=Regex.Match(message,@"\bat\s+([^\s]+)");var eta=Regex.Match(message,@"\bETA\s+([0-9:]+)");
                status.Text="下载中 "+m.Groups[1].Value+"%"+(speed.Success?" · "+speed.Groups[1].Value:"")+(eta.Success?" · 剩余 "+eta.Groups[1].Value:"");
            }}else if(message.Contains("开始下载作品文件"))status.Text="抖音正在下载 · 此方式暂不提供准确百分比";
            else if(message.Contains("文件下载成功"))status.Text="视频已下载 · 正在整理文件";
            else if(lastError!=null)status.Text="下载遇到问题 · 完成后查看原因";
        }
    }
    string FriendlyError(){
        string e=(lastError??"").ToLowerInvariant();
        if(e.Contains("ffmpeg"))return "音视频合并失败：请确认程序文件夹里有 ffmpeg.exe 和 ffprobe.exe。";
        if(e.Contains("403")||e.Contains("forbidden")||e.Contains("cookie"))return activeDouyin?"抖音访问受限或登录文件已过期，请重新导出 cookies.txt 后重试。":"平台拒绝访问，请确认链接和登录状态后重试。";
        if(e.Contains("unsupported url")||e.Contains("not a valid url"))return "链接不受支持，请复制视频页面的完整链接。";
        if(e.Contains("timeout")||e.Contains("network"))return "网络连接超时，请检查网络后重试。";
        return "下载失败，请查看下方详情后重试。";
    }
    void Done(int code){
        if(IsDisposed)return;if(InvokeRequired){BeginInvoke(new Action<int>(Done),code);return;}
        activeProcess=null;start.Enabled=true;cancel.Enabled=false;activity.Style=ProgressBarStyle.Continuous;
        lastFile=NewFile();openFile.Enabled=lastFile!=null;
        if(canceled){status.Text="已取消下载";retry.Enabled=true;Say("下载已取消；未完成的临时文件可能留在保存位置。");}
        else if(lastFile!=null&&code==0){activity.Value=100;status.Text="下载完成 · "+Path.GetFileName(lastFile);retry.Enabled=false;Say("下载完成："+Path.GetFileName(lastFile));}
        else if(code==0&&sawSkip){status.Text="这个视频可能已下载过，没有生成新文件";retry.Enabled=false;Say("已跳过重复的视频。");}
        else if(code==0&&lastError==null){status.Text="处理结束，但未发现新视频文件";retry.Enabled=true;Say("没有发现新视频；请查看上方提示或点击重试。");}
        else{status.Text=FriendlyError();retry.Enabled=true;Say(status.Text);}
    }
    void CancelDownload(){
        if(activeProcess==null)return;
        try{if(activeProcess.HasExited)return;canceled=true;cancel.Enabled=false;status.Text="正在取消…";activeProcess.Kill();}
        catch(Exception ex){canceled=false;cancel.Enabled=true;Say("取消失败："+ex.Message);}
    }
    void Download(object sender,EventArgs e) {
        string link=url.Text.Trim(); Uri uri;
        if(!Uri.TryCreate(link,UriKind.Absolute,out uri)||!(uri.Scheme=="http"||uri.Scheme=="https")){MessageBox.Show("请粘贴完整的视频链接。");return;}
        string dir=folder.Text.Trim();try{Directory.CreateDirectory(dir);}catch(Exception ex){MessageBox.Show("保存位置不可用："+ex.Message);return;}
        string host=uri.Host.ToLowerInvariant();
        bool douyin=host=="douyin.com"||host.EndsWith(".douyin.com");
        bool xhs=host=="xiaohongshu.com"||host.EndsWith(".xiaohongshu.com")||host=="xhslink.com";
        bool bili=host=="bilibili.com"||host.EndsWith(".bilibili.com")||host=="b23.tv";
        if(!douyin&&!xhs&&!bili){MessageBox.Show("目前只支持抖音、小红书和 B站的视频链接。", "链接不受支持");return;}
        if(douyin){var modal=Regex.Match(link,@"[?&]modal_id=(\d+)");if(modal.Success)link="https://www.douyin.com/video/"+modal.Groups[1].Value;}
        if(douyin&&!ValidCookieFile(cookies.Text)){cookies.Text=FindCookieFile()??"";if(!ValidCookieFile(cookies.Text)&&!ConfigureCookie())return;UpdateCookieStatus();}
        try{Directory.CreateDirectory(Path.GetDirectoryName(prefsPath));File.WriteAllText(prefsPath,json.Serialize(new Dictionary<string,string>{{"folder",dir},{"cookies",cookies.Text}}));}catch{}
        activeFolder=dir;activeDouyin=douyin;filesBefore=SnapshotFiles(dir);lastFile=null;lastError=null;sawSkip=false;canceled=false;
        start.Enabled=false;cancel.Enabled=true;retry.Enabled=false;openFile.Enabled=false;activity.Value=0;activity.Style=ProgressBarStyle.Marquee;status.Text="正在连接并准备下载…";log.Clear();Say("开始处理："+link);
        try{if(douyin) StartDouK(link,dir);else StartYtDlp(link,dir);}catch(Exception ex){if(douyin)ClearDouKCookie();lastError=ex.Message;Say("启动失败："+ex.Message);status.Text=FriendlyError();activity.Style=ProgressBarStyle.Continuous;start.Enabled=true;cancel.Enabled=false;retry.Enabled=true;}
    }
    void StartYtDlp(string link,string dir){
        string exe=Path.Combine(basePath,"yt-dlp.exe");if(!File.Exists(exe))throw new FileNotFoundException("缺少 yt-dlp.exe");
        string ffmpeg=Path.Combine(basePath,"ffmpeg.exe"),ffprobe=Path.Combine(basePath,"ffprobe.exe");
        if(!File.Exists(ffmpeg)||!File.Exists(ffprobe))throw new FileNotFoundException("缺少 ffmpeg.exe 或 ffprobe.exe，请完整解压程序包");
        var p=new Process();p.StartInfo.FileName=exe;p.StartInfo.Arguments="--newline --no-playlist --progress --no-mtime --ffmpeg-location \""+basePath.TrimEnd(Path.DirectorySeparatorChar)+"\" -P \""+dir.Replace("\"","")+"\" -o \"%(title).180B [%(id)s].%(ext)s\" \""+link.Replace("\"","")+"\"";
        p.StartInfo.UseShellExecute=false;p.StartInfo.CreateNoWindow=true;p.StartInfo.RedirectStandardOutput=true;p.StartInfo.RedirectStandardError=true;
        p.OutputDataReceived+=(s,e)=>{if(e.Data!=null)Say(e.Data);};p.ErrorDataReceived+=(s,e)=>{if(e.Data!=null)Say(e.Data);};
        p.EnableRaisingEvents=true;p.Exited+=(s,e)=>{int code=p.ExitCode;p.WaitForExit();Done(code);p.Dispose();};activeProcess=p;p.Start();p.BeginOutputReadLine();p.BeginErrorReadLine();
    }
    void ClearDouKCookie(){
        try{string config=Path.Combine(basePath,"DouK","Volume","settings.json");var clean=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(config,Encoding.UTF8));clean["cookie"]="";File.WriteAllText(config,json.Serialize(clean),new UTF8Encoding(false));}catch{}
    }
    void StartDouK(string link,string dir){
        string engine=Path.Combine(basePath,"DouK");string exe=Path.Combine(engine,"DouK-Downloader.exe");if(!File.Exists(exe))throw new FileNotFoundException("缺少 DouK 下载组件");
        string volume=Path.Combine(engine,"Volume"), config=Path.Combine(volume,"settings.json"), database=Path.Combine(volume,"DouK-Downloader.db");Directory.CreateDirectory(volume);
        var cfg=File.Exists(config)?json.Deserialize<Dictionary<string,object>>(File.ReadAllText(config,Encoding.UTF8)):new Dictionary<string,object>();
        if(cfg==null)cfg=new Dictionary<string,object>();
        var jar=new Dictionary<string,string>();foreach(string line in File.ReadAllLines(cookies.Text,Encoding.UTF8)){if((line.StartsWith("#")&&!line.StartsWith("#HttpOnly_"))||line.Trim().Length==0)continue;var f=line.Split(new[]{'\t'},7);if(f.Length==7&&IsDouyinCookieDomain(f[0])&&f[5].Length>0)jar[f[5]]=f[6];}
        if(jar.Count==0)throw new Exception("登录文件中没有有效的 Cookie，请重新导出。");
        string cleanDir=dir.TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);
        var parent=Directory.GetParent(cleanDir);
        if(parent==null)throw new Exception("抖音保存位置请选择磁盘中的文件夹，不能直接选择磁盘根目录。");
        cookieSecrets.Clear();foreach(string value in jar.Values)if(value.Length>=8)cookieSecrets.Add(value);
        cfg["cookie"]=jar;cfg["root"]=parent.FullName;cfg["folder_name"]=Path.GetFileName(cleanDir);cfg["tiktok_platform"]=false;cfg["run_command"]="";
        File.WriteAllText(config,json.Serialize(cfg),new UTF8Encoding(false));
        var p=new Process();p.StartInfo.FileName=exe;p.StartInfo.WorkingDirectory=engine;p.StartInfo.UseShellExecute=false;p.StartInfo.CreateNoWindow=true;
        p.StartInfo.RedirectStandardInput=true;p.StartInfo.RedirectStandardOutput=true;p.StartInfo.RedirectStandardError=true;
        p.OutputDataReceived+=(s,e)=>{if(e.Data!=null){if(e.Data.IndexOf("cookie",StringComparison.OrdinalIgnoreCase)>=0){if(e.Data.Contains("未设置")||e.Data.Contains("失败"))Say("抖音登录文件可能有问题，请重新导出并设置。");}else Say(e.Data);}};p.ErrorDataReceived+=(s,e)=>{if(e.Data!=null)Say(e.Data);};
        p.EnableRaisingEvents=true;p.Exited+=(s,e)=>{int code=p.ExitCode;p.WaitForExit();ClearDouKCookie();Done(code);p.Dispose();};
        bool first=!File.Exists(database);activeProcess=p;p.Start();p.BeginOutputReadLine();p.BeginErrorReadLine();
        if(first){p.StandardInput.WriteLine("1");p.StandardInput.WriteLine("YES");}
        p.StandardInput.WriteLine("5");p.StandardInput.WriteLine("2");p.StandardInput.WriteLine("1");p.StandardInput.WriteLine(link);p.StandardInput.WriteLine("Q");p.StandardInput.Close();
    }
    [STAThread]static void Main(){Application.EnableVisualStyles();Application.Run(new UnifiedDownloader());}
}
