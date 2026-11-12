# SPDX-License-Identifier: GPL-3.0-or-later
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$build = Join-Path $project 'build\windows'
$vendor = Join-Path $build 'vendor'
$stage = Join-Path $build 'stage'
$dist = Join-Path $project 'dist'
New-Item -ItemType Directory -Force -Path $vendor,$dist | Out-Null

function Get-CheckedFile([string]$Url,[string]$Path,[string]$Expected) {
    if (-not (Test-Path $Path)) { Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Path }
    $actual = (Get-FileHash -Algorithm SHA256 $Path).Hash.ToLowerInvariant()
    if ($actual -ne $Expected) { throw "SHA-256 mismatch: $Path ($actual)" }
}

$doukZip = Join-Path $vendor 'douk-windows-x64.zip'
$ytDlp = Join-Path $vendor 'yt-dlp.exe'
$ffmpegZip = Join-Path $vendor 'ffmpeg-9.0.2-essentials_build.zip'
Get-CheckedFile 'https://github.com/JoeanAmier/TikTokDownloader/releases/download/5.8/DouK-Downloader_V5.8_Windows_X64.zip' $doukZip 'c96342ef1256b708b26ab742cac2e6f29aed78e40c82d52098af01737951910c'
Get-CheckedFile 'https://github.com/yt-dlp/yt-dlp/releases/download/2026.10.26/yt-dlp.exe' $ytDlp 'f5389d3698ecde4ef06f4e6b1ce0294fe9ac1396228c8990b8d3416d6d177a7d'
Get-CheckedFile 'https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-9.0.2-essentials_build.zip' $ffmpegZip '60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba'

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $stage 'DouK') | Out-Null
Expand-Archive -LiteralPath $doukZip -DestinationPath (Join-Path $stage 'DouK')
$ffmpegWork = Join-Path $build 'ffmpeg'
if (Test-Path $ffmpegWork) { Remove-Item $ffmpegWork -Recurse -Force }
Expand-Archive -LiteralPath $ffmpegZip -DestinationPath $ffmpegWork
$ffmpeg = Get-ChildItem $ffmpegWork -Filter ffmpeg.exe -Recurse | Select-Object -First 1
$ffprobe = Get-ChildItem $ffmpegWork -Filter ffprobe.exe -Recurse | Select-Object -First 1
if (-not $ffmpeg -or -not $ffprobe) { throw 'FFmpeg archive missing ffmpeg.exe or ffprobe.exe' }
foreach ($path in @($ffmpeg.FullName,$ffprobe.FullName,$ytDlp)) { Copy-Item -LiteralPath $path -Destination $stage }
foreach ($name in @('app-icon.ico','app-icon.png')) { Copy-Item -LiteralPath (Join-Path $project ('windows\' + $name)) -Destination $stage }
Copy-Item (Join-Path $project 'docs\Windows-User-Guide.txt') (Join-Path $stage 'README-Windows.txt')
Copy-Item -LiteralPath (Join-Path $project 'LICENSE') -Destination $stage
Copy-Item -LiteralPath (Join-Path $project 'windows\UnifiedDownloader.cs') -Destination $stage
Copy-Item -LiteralPath (Join-Path $project 'windows\THIRD_PARTY.txt') -Destination $stage
$ffmpegLicense = Get-ChildItem $ffmpegWork -Filter LICENSE -Recurse | Select-Object -First 1
if ($ffmpegLicense) { Copy-Item -LiteralPath $ffmpegLicense.FullName -Destination (Join-Path $stage 'FFmpeg-LICENSE.txt') }

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw 'Windows .NET Framework 4.x csc.exe not found' }
$outArg = '/out:' + (Join-Path $stage 'VideoDownloader.exe')
$iconArg = '/win32icon:' + (Join-Path $project 'windows\app-icon.ico')
& $csc /nologo /codepage:65001 /target:winexe $outArg $iconArg /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll (Join-Path $project 'windows\UnifiedDownloader.cs')
if ($LASTEXITCODE -ne 0) { throw 'C# compilation failed' }
$zip = Join-Path $dist 'VideoDownloader-Windows-x64.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
Write-Host "Built $zip"
Write-Host 'This package still requires real Windows download and UI tests before release.'
