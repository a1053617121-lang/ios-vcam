@echo off
REM ======================================
REM Virtual Camera Pro - Stream Starter
REM Converts OBS RTMP to HTTP for iPhone
REM ======================================

echo.
echo ======================================
echo Virtual Camera Pro - Stream Server
echo ======================================
echo.
echo Starting RTMP to HTTP converter...
echo.
echo OBS Stream: rtmp://localhost:1935/live/stream
echo HTTP Stream: http://localhost:8888/live
echo.
echo iPhone should connect to your local IP address.
echo Example: http://192.168.1.XX:8888/live
echo.
echo Press CTRL+C to stop streaming
echo.

REM Check if FFmpeg is installed
where ffmpeg >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: FFmpeg not found!
    echo.
    echo Please download FFmpeg from:
    echo https://www.gyan.dev/ffmpeg/builds/ffmpeg-full.7z
    echo.
    echo Or use Windows Store:
    echo winget install FFmpeg
    echo.
    pause
    exit /b 1
)

REM ============================================================
REM 声音支持说明：
REM 1) 下面的 MJPEG 命令 = 纯画面（无音频），iPhone 端推流声音
REM    来自 iPhone 麦克风（audioMode=0，默认）。
REM 2) 想要"电脑端 OBS 的声音"也进推流，请改用"带音频的 HLS"
REM    （MJPEG 格式本身不支持音频），然后：
REM    - iPhone 端 streamURL 设为
REM      http://192.168.1.XX:8888/live/stream/index.m3u8
REM    - 配置文件 audioMode 设为 1（注入流声音）
REM ============================================================

REM 方案A（默认，纯画面）：OBS 画面 + iPhone 麦克风声音
REM ffmpeg -i rtmp://localhost:1935/live/stream ^
REM     -vcodec mjpeg ^
REM     -q:v 5 ^
REM     -f mpjpeg ^
REM     -listen 1 ^
REM     http://0.0.0.0:8888/live

REM ============================================================
REM 方案B（推荐，带声音）：
REM 第一步：ffmpeg 把 RTMP 转成本地 HLS（视频 MJPEG + 音频 AAC）
REM 第二步：python 起 HTTP 服务，iPhone 用 HLS 拉流
REM 窗口1（本窗口）：
REM ============================================================
mkdir E:\stream\live\stream 2>nul
ffmpeg -i rtmp://localhost:1935/live/stream ^
    -c:v mjpeg -q:v 5 ^
    -c:a aac -b:a 128k ^
    -f hls -hls_time 2 -hls_list_size 5 -hls_flags delete_segments ^
    E:\stream\live\stream\index.m3u8

REM 然后另开一个窗口执行：
REM     python -m http.server 8888 --directory E:\stream
REM iPhone 端 streamURL 填：http://192.168.1.XX:8888/live/stream/index.m3u8
REM 配置 audioMode=1 注入流声音。

pause
