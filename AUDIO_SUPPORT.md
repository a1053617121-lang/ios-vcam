# AVFCameraSupport 音频支持说明（AUDIO_SUPPORT）

版本：在 14.8.3 基础上新增音频支持，构建产物版本号建议提升为 14.9.0（可选，见文末）。

## 一、为什么之前推流没有声音

排查源码后确认，原版存在三处"声音缺失"：

1. **转流链路**（`start-stream.bat`）：`ffmpeg` 只转了视频（`-vcodec mjpeg`），输出是纯 MJPEG 流——**MJPEG 格式本身不支持音频**，电脑端 OBS 的声音根本进不了流。
2. **流播放器**（`AVAssetStreamAdapter.m`）：HLS 分支里 `self.hlsPlayer.muted = YES;`，流的声音被强制静音，且没有把音频取出来的任何逻辑。
3. **Tweak 注入**（`Tweak.x`）：只 hook 了视频输出（`AVCaptureVideoDataOutput` / 预览层 / 拍照），音频输出（`AVCaptureAudioDataOutput`）完全没有被处理。

## 二、本次修改内容

| 文件 | 改动 |
| --- | --- |
| `Tweak.x` | 新增 `AVCaptureAudioDataOutput` hook；新增 `audioMode` 配置（0=透传麦克风 / 1=注入流声音）；新增全局音频缓冲 `_audioBuf`；adapter 增加音频回调 |
| `AVAssetStreamAdapter.h` | 新增音频采样回调类型 `AVAssetAudioSampleBufferCallback` 与属性 `audioSampleBufferCallback` |
| `AVAssetStreamAdapter.m` | 新增 HLS 音频轨提取（`startAudioExtraction`：AVAssetReader 读音频轨，逐帧回调）；MJPEG 无音频，跳过 |
| `Makefile` | 链接 `AudioToolbox` framework |
| `VirtualCamPro.plist` | Filter 增加 `AVCaptureAudioDataOutput` 类 |
| `prefs/Resources/Root.plist` | 设置面板新增 "Stream Audio" 开关（对应 `audioMode`） |
| `example-config.plist` / `setup-config.sh` | 配置模板增加 `audioMode` 键 |
| `start-stream.bat` | 新增"带声音"的 HLS 转流方案（替代 MJPEG） |

## 三、工作原理

```
OBS (RTMP) ──ffmpeg──> HLS(m3u8, 视频+音频) ──HTTP──> iPhone

iPhone 端：
  Tweak.x 拦截 AVCaptureVideoDataOutput → 画面换成流画面（原有逻辑）
  AVAssetStreamAdapter 额外用 AVAssetReader 读出流的音频轨 → 逐帧回调
  Tweak.x 拦截 AVCaptureAudioDataOutput →
      audioMode=1 且格式匹配：把麦克风音频帧替换为流音频帧 → 推流带"流的声音"
      audioMode=0 或格式不匹配：原样透传 → 推流带"麦克风的声音"（兜底）
```

音频注入带**格式保护**：只有流音频与 App 期望格式（formatID / 采样率 / 声道数）完全一致时才替换，否则自动降级为透传，**不会因为格式不同导致崩溃**。

## 四、配置方法

配置文件：`/var/mobile/Library/Preferences/com.apple.avfoundation.cs.plist`

```xml
<key>audioMode</key>
<integer>1</integer>   <!-- 1=注入流声音（推荐），0=透传麦克风 -->
```

或直接在"设置"App → VirtualCamPro → "Stream Audio" 开关里切换。

## 五、推流带声音的完整步骤（电脑端）

1. OBS 正常推流到 `rtmp://localhost:1935/live/stream`（OBS 的音频要开着）。
2. 运行 `start-stream.bat`（已改为带音频方案）：
   - 它会用 ffmpeg 把 RTMP 转成本地 HLS（视频 + AAC 音频），写入 `E:\stream\live\stream\`。
3. 另开一个窗口，起 HTTP 服务：
   ```
   python -m http.server 8888 --directory E:\stream
   ```
4. iPhone 上（用 Filza/Sileo 图形界面，勿用终端）把配置文件的 `streamURL` 改为：
   ```
   http://192.168.1.XX:8888/live/stream/index.m3u8
   ```
   （XX 换成电脑的局域网 IP）
5. `audioMode` 设为 1，重启摄像头相关 App。此时推流画面=OBS 画面，声音=OBS 里的声音。

> 若你不需要电脑端声音，只想推流带 iPhone 自己的麦克风声音：`audioMode` 保持 0（默认），用原来的 MJPEG 方案即可。

## 六、构建方法（生成 .deb）

本机 Windows 没有 iOS SDK，无法本地编译；项目已带 GitHub Actions workflow，构建步骤如下：

1. 把本目录内容替换到你 fork 的 `ios-vcam` 仓库（或直接用压缩包里的源码覆盖）。
2. 推送到 GitHub（`git add . && git commit -m "add audio support" && git push`）。
3. Actions 自动构建，约 3~5 分钟后在 Artifacts 下载 `VirtualCamPro_deb` 包里的
   `com.apple.avfoundation.camerasupport_14.8.3_iphoneos-arm64e.deb`。
4. 用 Sileo/Filza 图形界面安装。

可选：把 `control` 里 `Version: 14.8.3` 改成 `14.9.0`，避免覆盖旧版本。

## 七、已知限制（重要）

1. **HLS 音频提取依赖 AVAssetReader**：苹果对 HLS 直播流的 AVAssetReader 支持有限（点播 m3u8 多数可用，低延迟/滑动窗口直播流可能读取失败）。失败时自动降级为麦克风透传（推流仍有声音，只是不是流的声音）。这是 iOS 系统级限制，无公开 API 可从 AVPlayer 直接取音频帧。
2. **格式匹配才注入**：流的音频采样率/声道与 App 期望不一致时自动透传，不强行转换（避免崩溃）。
3. **时间戳**：注入的流音频帧时间戳来自流时间轴，部分 App 可能出现轻微音画不同步；多数编码器只按格式解码，影响不大。
4. **MJPEG 链路**（原方案）本身无音频，走这条链路时声音只能来自 iPhone 麦克风。

## 八、验证建议

- 先用 `audioMode=0` 测推流是否有人声（排除 App/权限问题）。
- 再开 HLS 带声音链路 + `audioMode=1` 测"流的声音"是否进入推流。
- 若某 App 推流崩溃：把 `audioMode` 切回 0 即恢复，说明该 App 音频格式特殊，属预期降级。
