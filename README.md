# 兰台阅读 · 鸿蒙端

HarmonyOS 原生客户端（`org.lantai.reader`）。当前 **0.3.0**（`versionCode 1000300`）：全部屏建成并接真实服务端数据，EPUB 走 ArkWeb 复用兰台 `ebook.js`，漫画/本机库/离线下载为原生实现。

- 代码 74 个 `.ets` / 约 27,300 行；真机包 11.4 MB（仅 arm64）
- 进度与包体见 `../文档指南/版本记录.md`，细节见 `../文档指南/开发记录.md`，方案见 `../文档指南/方案/`
- 界面现状：首页顶栏只保留品牌标识（无标题、无数量与更新时间、无搜索按钮），统计页无右上角 `⋯`，应用图标为兰台品牌 logo

## 目录

```
entry/src/main/ets/
├── common/          Theme（配色/字体/圆角）、Format、Json、Icons（Canvas 描边图标）、ImageOps（taskpool 裁边校色）、
│                    I18n + StrEn + StrTpl（中英文案与数字模板）、ProgressMarks、WindowFx、AppCtx
├── model/           LantaiModels（BookItem/BookQuery/Chapter/Stats/Series + mapper）、AppStore（会话单例）、Prefs、
│                    ServerProfile（serverKey 指纹）、ProbeModel
├── net/             会话与网络：LantaiSession（Cookie）、LantaiApi、ResourceProxy、NativeBridge、AutoSwitch、LanScan、UpdateChecker
│                    本地库：LocalLibrary、LocalMeta、LocalStore、LocalBookSource、LocalFiles、ZipBook、ComicArchive
│                    离线：OfflineCache、OfflineDownloader、BackgroundTask、CacheQuota、CachePurge、OrphanSweep、SeriesCache
│                    进度与朗读：ProgressOutbox、ReadingSession、TtsService、TtsSession
├── data/            OfflineDb（RDB：JOB / OFFLINE_BOOK / PROGRESS_OUTBOX / READING_SESSION）
├── components/      CoverCache（PixelMap LRU）、CoverImage、CoverViewer、BookViews、Skeletons、StateViews、
│                    Shell（玻璃顶栏 + 浮动底栏）、ReaderGuide（引导遮罩）、ReadingWeb（常驻 Web 阅读壳）、TtsBar、Icon
└── pages/           Index（唯一 @Entry）、MainShell、Login、Home、Library、BookDetail、SeriesDetail、Reader（EPUB/ArkWeb）、
                     ComicReader、Import、Downloads、Collections、Readlists、Annotations、Sources、Server、Prefs、Stats、Mine、TtsProbe
```

## 能力

| 域 | 状态 |
|---|---|
| 登录 / 会话 | Basic → `Set-Cookie` → 逐请求注入，`preferences` 持久化，启动探 `/api/v2/users/me` 免登录 |
| 书库 | 来源筛选、按系列/网格/列表三视图、7 维筛选、服务端分页、下拉刷新、卡片与系列阅读进度 |
| EPUB | ArkWeb + `ebook.js`（虚拟同源 `https://lantai.example` + `setWebSchemeHandler` 转发注入 Cookie），目录/标注/设置三面板 |
| 漫画 | 单页 / 双页 / 长条 / 分页四模式，双指缩放，裁白边，LUT 校色（均走 taskpool） |
| 本机库 | 目录授权（API 26）或文件多选，CBZ/ZIP/RAR/7Z 解压，TXT/EPUB/PDF 阅读 |
| 离线 | 下载队列 + 断点续传 + 长时任务，离线副本可读，进度补报队列 |
| 统计 / 心跳 | 30 天统计、20 s 心跳、离线会话同步（`reading/sync`，只删 confirmed） |
| 其他 | 待读、标记已读/未读、批注书签、系列合集与书单（写入需 ADMIN）、隐身阅读 |

## 构建

```bash
node.exe "<DevEco>/tools/hvigor/bin/hvigorw.js" --mode module -p product=default assembleHap --no-daemon
```

`hmosCode` 下没有 `hvigorw.js` 也没有 `node_modules`，必须用 DevEco 自带的那份。产物在 `entry/build/default/outputs/default/`。

出包统一走仓库根的 `python release.py app`：默认 patch +1（`--no-bump` 重出当前版本、`--version x.y.z` 指定）、自动 `clean`、临时摘除 `signingConfig` 出无证书包、生成 `.sha256` 并追加 `../文档指南/构建记录.md`。`versionCode = 1000000 + minor×100 + patch`。

**ABI**：依赖 `@ohos/unrar` / `@ohos/oh7zip` 带三 ABI 预编译 so，真机包用 `entry/build-profile.json5` 的 `buildOption.nativeLib.filter.select[].excludePattern` 排掉 `armeabi-v7a` 与 `x86_64`。**回模拟器调试要临时去掉 `**/x86_64/**`，验完恢复**。`buildOption.abiFilters` 不合法（schema 校验失败）。

## 运行

1. 服务端（`Lantai`）启动，确认设备可访问 `http://<主机>:<端口>`
2. `hdc install` 装包，首屏填服务器地址 + 用户名 + 密码
3. 首页聚合 → 书库（`POST /api/v1/books/list`）→ 详情 → EPUB/漫画阅读器

## 环境限制

- 模拟器（API 24）：无 `DocumentSelectMode.FOLDER`、无 PDF syscap、无法向 picker 可见目录投文件、非 root 不能断网 → 这些只能在 API 26 真机验证
- 签名不一致时 `hdc install` 报 `9568332 sign info inconsistent`，需先 `hdc uninstall`（会清登录态与本地库）
- `hdc install` 传绝对路径会被拼上 cwd，必须 `cd` 到包目录用相对名；bash 下需 `export MSYS_NO_PATHCONV=1`
- `uitest uiInput inputText` 是 `<x> <y> <text>` 三参数且为追加语义（退格 `keyEvent 2055`）；控件坐标一律用 `dumpLayout` 的 bounds，别按截图估
- 密码框聚焦时安全键盘阻断截屏，验证前先 `keyEvent Back`
- Web 不可见时 `loadUrl` 静默失效，必须等可见后延迟 600 ms；域名不能带 `.local`

## 已踩的关键坑

- `@Builder` 按值传参在首帧后不刷新 → 一律 `@Component` + `@Prop`（`metaRow`/`filterRow`/`statLine`/分页按钮）
- `ForEach` 的 key 必须覆盖所有会变字段，否则静默复用旧节点
- `@Prop` 名不能与通用属性同名（`enabled` / `scale` / `size` 都会编译失败）
- 自定义组件不能叫 `Icon`（与内置重名，运行时不执行自己的实现）
- `http.RequestMethod` 无 `PATCH`；204 空响应 `response.result` 是 `undefined`
- `PixelMap` 不能跨线程；`@Concurrent` 不能引用模块级变量

## 效果预览与演示数据

`../UI设计/兰台阅读-LantaiReader-手机端UI.html` 是纯静态效果预览，其中全部书名、作者、出版社、系列名、章节目录、正文段落、标注与引文均为 **AI 生成的演示文本**。

- 不代表任何真实媒体内容，也不指代任何版权物
- 如与既有作品、人物、机构重名，纯属巧合；该名称仅说明对应词条在 AI 数据库中出现频次较高，与本项目无任何关联
- ISBN 统一为不可校验的 `978-7-9999-*` 测试号，书目外链统一指向 `example.com` 示例域
- 预览数据只存在于 `UI设计/` 目录，不参与构建、不进入 `entry/src/main/resources`，与真机运行时的服务端数据无关
