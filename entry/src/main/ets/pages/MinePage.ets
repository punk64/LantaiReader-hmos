import { bundleManager } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { promptAction } from '@kit.ArkUI';
import { C, FT, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { appStore } from '../model/AppStore';
import { Prefs, PrefKeys } from '../model/Prefs';
import {
  BookPage,
  BookQuery,
  CollectionCard,
  ReadListSummary,
  ReadingStats,
  emptyQuery
} from '../model/LantaiModels';
import { JobRow, OfflineBookRow, offlineDb } from '../data/OfflineDb';
import { progressOutbox } from '../net/ProgressOutbox';
import { readingTracker } from '../net/ReadingSession';
import { AutoSwitch } from '../net/AutoSwitch';
import { ActionBtn, GroupHead, NavRow, ScreenHead, ToggleRow } from '../components/Shell';
import { Lang, t } from '../common/I18n';
import { UpdateChecker, UpdateResult } from '../net/UpdateChecker';
import { readerWeb } from '../components/ReadingWeb';
interface MineMetric {
  value: string;
  label: string;
}

function emptyMetrics(): MineMetric[] {
  return [
    { value: '—', label: t('藏书') },
    { value: '—', label: t('在读') },
    { value: '—', label: t('离线') },
    { value: '—', label: t('本月') }
  ];
}

@CustomDialog
struct AboutDialog {
  @StorageLink('uiTick') uiTick: number = 0;
  controller?: CustomDialogController;
  @State version: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const info: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.version = info.versionName;
    } catch (error) {
      this.version = '';
    }
  }

  build() {
    Column({ space: 0 }) {
      Image($r('app.media.logo_lantai'))
        .width(62)
        .height(62)
        .borderRadius(18)
        .clip(true)
        .border({ width: 1, color: C.accLine })

      Text(t('兰台阅读'))
        .fontSize(19)
        .fontFamily(FT.disp)
        .letterSpacing(4)
        .fontColor(C.acc2)
        .margin({ top: 14 })

      Text(this.version.length > 0 ? `LANTAI READER · ${this.version}` : 'LANTAI READER')
        .fontSize(8.5)
        .fontFamily(FT.mono)
        .letterSpacing(1.6)
        .fontColor(C.tx4)
        .margin({ top: 6 })

      Text(t('本地书库阅读客户端。仅面向个人与家庭自用，不提供公开注册与分享、不提供收费代下、不与任何预置内容源捆绑分发。'))
        .fontSize(10.5)
        .fontColor(C.tx3)
        .lineHeight(18)
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })

      Text(t('不含任何在线书源、文本源客户端或书籍抓取引擎。'))
        .fontSize(10.5)
        .fontColor(C.tx3)
        .lineHeight(18)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })

      Text(t('关闭'))
        .fontSize(12)
        .fontColor(C.acc)
        .textAlign(TextAlign.Center)
        .height(36)
        .width('100%')
        .margin({ top: 18 })
        .backgroundColor(C.bg3)
        .borderRadius(10)
        .onClick(() => {
          this.controller?.close();
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 24, bottom: 18 })
    .backgroundColor(C.bg1)
    .borderRadius(R.l)
    .border({ width: 1, color: C.line })
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct MinePage {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('netTick') @Watch('onNetTick') netTick: number = 0;
  @StorageLink('profileTick') @Watch('onProfileTick') profileTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State autoSync: boolean = true;
  @State incognito: boolean = false;
  @State wifiOnly: boolean = true;
  @StorageLink('serverCount') serverCount: number = 0;
  @State metrics: MineMetric[] = emptyMetrics();
  @State queueLabel: string = t('读取中');
  @State outboxLabel: string = t('读取中');
  @State listLabel: string = t('读取中');
  @State collectionLabel: string = t('读取中');
  @State storageLabel: string = t('读取中');
  @State themeLabel: string = '';
  @State langLabel: string = '';
  @State updateLabel: string = '';
  @State version: string = '';
  @State face: image.PixelMap | undefined = undefined;
  @State nameText: string = '';
  @State connText: string = '';
  @State editingRepo: boolean = false;
  @State repoDraft: string = '';
  onOpenTab: (index: number) => void = () => {};
  private about: CustomDialogController = new CustomDialogController({
    builder: AboutDialog(),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    this.wifiOnly = Prefs.bool('wifiOnly', true);
    this.refreshLabels();
    this.refreshIdentity();
    this.loadMetrics();
    this.loadVersion();
  }

  private refreshIdentity(): void {
    this.face = appStore.avatar;
    this.nameText = appStore.displayName();
    this.connText = appStore.connectionLabel();
  }

  private onNetTick(): void {
    this.refreshIdentity();
  }

  private onProfileTick(): void {
    this.refreshIdentity();
  }

  private initial(): string {
    return this.nameText.length > 0 ? this.nameText.substring(0, 1).toUpperCase() : t('读');
  }

  private refreshLabels(): void {
    this.themeLabel = C.mode === 'light' ? t('浅色') : t('深色');
    this.langLabel = Lang.label();
    this.repoDraft = UpdateChecker.source();
  }

  private async loadVersion(): Promise<void> {
    try {
      const info: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.version = info.versionName;
    } catch (error) {
      this.version = '';
    }
  }

  private async pickTheme(): Promise<void> {
    try {
      const result: promptAction.ActionMenuSuccessResponse = await promptAction.showActionMenu({
        title: t('外观主题'),
        buttons: [
          { text: t('深色'), color: C.acc },
          { text: t('浅色'), color: C.acc }
        ]
      });
      const mode: string = result.index === 1 ? 'light' : 'dark';
      C.apply(mode);
      await Prefs.write(PrefKeys.uiTheme, mode);
      this.refreshLabels();
    } catch (error) {
    }
  }

  private async pickLang(): Promise<void> {
    try {
      const result: promptAction.ActionMenuSuccessResponse = await promptAction.showActionMenu({
        title: t('界面语言'),
        buttons: [
          { text: '简体中文', color: C.acc },
          { text: 'English', color: C.acc },
          { text: '日本語', color: C.acc }
        ]
      });
      const codes: string[] = ['zh', 'en', 'ja'];
      Lang.apply(codes[result.index] ?? 'zh');
      readerWeb.invalidate();
      this.refreshLabels();
      this.loadMetrics();
    } catch (error) {
    }
  }

  private async checkUpdate(): Promise<void> {
    this.updateLabel = t('检查中…');
    const result: UpdateResult = await UpdateChecker.check(this.version);
    if (result.state === 'new') {
      this.updateLabel = t('发现新版本') + ' · ' + result.version;
      promptAction.showDialog({
        title: t('发现新版本') + ' · ' + result.version,
        message: result.notes.length > 0 ? result.notes : t('当前版本') + ' ' + this.version,
        buttons: [
          { text: t('关闭'), color: C.tx3 },
          { text: t('下载'), color: C.acc }
        ]
      });
    } else if (result.state === 'latest') {
      this.updateLabel = t('已是最新版本');
      promptAction.showToast({ message: t('已是最新版本') + ' · ' + this.version });
    } else {
      const reason: string = result.message === 'NO_RELEASE'
        ? t('未找到 release')
        : (result.message === 'INVALID_SOURCE' ? t('更新源无效') : t('检查失败'));
      this.updateLabel = reason;
      promptAction.showToast({ message: reason + ' · ' + UpdateChecker.source() });
    }
  }

  private async saveRepo(): Promise<void> {
    const text: string = this.repoDraft.trim();
    if (text.length === 0) {
      promptAction.showToast({ message: t('更新源无效') });
      return;
    }
    await UpdateChecker.saveRepo(text);
    this.editingRepo = false;
    this.updateLabel = '';
    promptAction.showToast({ message: t('已保存') });
  }

  private async loadOfflineMetrics(): Promise<void> {
    try {
      const rows: OfflineBookRow[] = await offlineDb.books();
      let bytes: number = 0;
      for (let index: number = 0; index < rows.length; index++) {
        bytes += rows[index].bytes;
      }
      this.storageLabel = t(`${rows.length} 本离线 · ${F.bytes(bytes)}`);
      this.metrics = [
        { value: `${appStore.localMetas.length + rows.length}`, label: t('藏书') },
        { value: '—', label: t('在读') },
        { value: `${rows.length}`, label: t('离线') },
        { value: '—', label: t('本月') }
      ];
      this.queueLabel = t('离线模式不可用');
      this.listLabel = t('离线模式不可用');
      this.collectionLabel = t('离线模式不可用');
    } catch (error) {
      this.metrics = emptyMetrics();
      this.storageLabel = t('读取失败');
    }
    try {
      const pending: number = await progressOutbox.count();
      const sessions: number = await readingTracker.pendingCount();
      const total: number = pending + sessions;
      this.outboxLabel = total > 0 ? t(`${total} 条待上报`) : t('无积压');
    } catch (error) {
      this.outboxLabel = t('读取失败');
    }
  }

  private async loadMetrics(): Promise<void> {
    if (appStore.offline) {
      await this.loadOfflineMetrics();
      return;
    }
    try {
      const query: BookQuery = emptyQuery();
      query.size = 1;
      query.sort = 'lastModified,desc';
      const page: BookPage = await appStore.api.books(query);
      const stats: ReadingStats = await appStore.api.readingStats();
      const offline: OfflineBookRow[] = await offlineDb.books();
      let offlineBytes: number = 0;
      for (let index: number = 0; index < offline.length; index++) {
        offlineBytes += offline[index].bytes;
      }
      this.storageLabel = t(`${offline.length} 本离线 · ${F.bytes(offlineBytes)}`);
      this.metrics = [
        { value: `${page.total}`, label: t('藏书') },
        { value: `${stats.bookCount}`, label: t('在读') },
        { value: `${offline.length}`, label: t('离线') },
        { value: F.shortDuration(stats.totalDurationMs), label: t('本月') }
      ];
    } catch (error) {
      this.metrics = emptyMetrics();
      this.storageLabel = t('读取失败');
    }
    try {
      const jobs: JobRow[] = await offlineDb.jobs();
      let running: number = 0;
      let waiting: number = 0;
      for (let index: number = 0; index < jobs.length; index++) {
        if (jobs[index].state === 'RUNNING') {
          running += 1;
        } else if (jobs[index].state === 'PENDING' || jobs[index].state === 'PAUSED') {
          waiting += 1;
        }
      }
      this.queueLabel = jobs.length === 0 ? t('空闲') : t(`${running} 项进行中 · ${waiting} 项等待中`);
      const pending: number = await progressOutbox.count();
      const sessions: number = await readingTracker.pendingCount();
      const total: number = pending + sessions;
      this.outboxLabel = total > 0 ? t(`${total} 条待上报`) : t('无积压');
    } catch (error) {
      this.queueLabel = t('读取失败');
      this.outboxLabel = t('读取失败');
    }
    try {
      const lists: ReadListSummary[] = await appStore.api.readlists();
      this.listLabel = t(`${lists.length} 个`);
    } catch (error) {
      this.listLabel = t('读取失败');
    }
    try {
      const collections: CollectionCard[] = await appStore.api.collections();
      this.collectionLabel = collections.length > 0 ? t(`${collections.length} 个`) : t('暂无');
    } catch (error) {
      this.collectionLabel = t('读取失败');
    }
  }

  private async goOnline(): Promise<void> {
    if (!appStore.offline) {
      return;
    }
    const restored: boolean = await appStore.exitOffline();
    if (!restored) {
      promptAction.showToast({
        message: this.serverCount > 0 ? t('会话已失效，请从登录页重新登录') : t('尚未登录，请从登录页登录')
      });
      return;
    }
    await progressOutbox.flush(appStore.session);
    await readingTracker.flush(appStore.session);
    AutoSwitch.start();
    promptAction.showToast({ message: t('已切回在线') });
    appStore.notifyOffline();
  }

  private goOffline(): void {
    if (appStore.offline) {
      return;
    }
    appStore.enterOffline();
  }

  private backToLogin(): void {
    AppStorage.setOrCreate('loginTick', Date.now());
  }

  private async logout(): Promise<void> {
    const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: t('退出登录'),
      message: t('将清除本机登录凭据。离线副本与阅读进度保留在本机，重新登录后可继续使用。'),
      buttons: [
        { text: t('取消'), color: C.tx3 },
        { text: t('退出'), color: C.bad }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    await appStore.logout();
    AppStorage.setOrCreate('logoutTick', Date.now());
  }

  private go(route: string): void {
    this.nav.pushPathByName(route, null);
  }

  @Builder
  userCard() {
    Row({ space: 12 }) {
      if (this.face !== undefined) {
        Image(this.face)
          .width(46)
          .height(46)
          .objectFit(ImageFit.Cover)
          .borderRadius(14)
          .border({ width: 1, color: C.accLine })
          .draggable(false)
      } else {
        Text(this.initial())
          .fontSize(17)
          .fontColor(C.acc2)
          .textAlign(TextAlign.Center)
          .width(46)
          .height(46)
          .backgroundColor(C.accBg)
          .borderRadius(14)
          .border({ width: 1, color: C.accLine })
      }

      Column({ space: 2 }) {
        Text(this.nameText)
          .fontSize(15)
          .fontColor(C.tx)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(appStore.offline ? t('离线模式 · 仅本机内容')
          : `${t('已连接')} ${this.connText} · ${t('双来源可用')}`)
          .fontSize(10)
          .fontColor(C.tx4)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(appStore.offline ? t('离线') : t('在线'))
        .fontSize(9)
        .fontColor(appStore.offline ? C.acc2 : C.ok)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(3)
        .border({ width: 1, color: appStore.offline ? C.accLine : C.ok })
    }
    .width('100%')
    .padding({ left: 13, right: 13, top: 13, bottom: 13 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  metricCard() {
    Row() {
      ForEach(this.metrics, (item: MineMetric, index: number) => {
        Column({ space: 2 }) {
          Text(item.value)
            .fontSize(16.5)
            .fontColor(C.acc2)
          Text(t(item.label))
            .fontSize(9.5)
            .fontColor(C.tx4)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .border({ width: { right: index === this.metrics.length - 1 ? 0 : 1 }, color: C.line })
      }, (item: MineMetric, index: number) => `${index}-${item.label}-${item.value}`)
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .margin({ top: 10 })
  }

  @Builder
  repoEditor() {
    Row({ space: 8 }) {
      TextInput({ text: this.repoDraft, placeholder: t('owner/repo 或 https://…') })
        .layoutWeight(1)
        .height(34)
        .fontSize(12)
        .backgroundColor(C.bg2)
        .fontColor(C.tx)
        .placeholderColor(C.tx4)
        .borderRadius(8)
        .padding({ left: 9, right: 9 })
        .onChange((text: string) => {
          this.repoDraft = text;
        })
      Text(t('保存'))
        .fontSize(12)
        .fontColor(C.acc)
        .onClick(() => {
          this.saveRepo();
        })
      Text(t('取消'))
        .fontSize(12)
        .fontColor(C.tx3)
        .onClick(() => {
          this.repoDraft = UpdateChecker.source();
          this.editingRepo = false;
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  build() {
    Column() {
      ScreenHead({ brand: true, title: t('我的'), sub: '' })

      Scroll() {
        Column() {
          this.userCard()
          this.metricCard()

          GroupHead({ title: t('书库与存储') })
          Column({ space: 0 }) {
            NavRow({ glyph: 'folder', title: t('来源与存储'), sub: t(`${this.storageLabel} · 本地库 / 云库`), onTap: () => {
              this.go('sources');
            } })
            NavRow({ glyph: 'upload', title: t('导入本地文件'), sub: t('不上传、不复制两份'), onTap: () => {
              this.go('import');
            } })
            NavRow({ glyph: 'download', title: t('下载队列'), sub: this.queueLabel, onTap: () => {
              this.go('downloads');
            } })
          }
          .width('100%')
          .padding({ left: 13, right: 13 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          GroupHead({ title: t('连接与同步') })
          Column() {
            Row({ space: 8 }) {
              Column({ space: 2 }) {
                Text(appStore.offline ? t('离线模式') : t('在线模式'))
                  .fontSize(12.5)
                  .fontColor(C.tx)
                  .width('100%')
                Text(appStore.offline ? t('只显示已下载的云库书与本地书') : this.connText)
                  .fontSize(9.5)
                  .fontColor(C.tx4)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text(t('在线'))
                .fontSize(11)
                .fontColor(appStore.offline ? C.tx2 : C.onAcc)
                .textAlign(TextAlign.Center)
                .width(56)
                .height(28)
                .backgroundColor(appStore.offline ? C.bg2 : C.acc)
                .borderRadius(8)
                .border({ width: 1, color: appStore.offline ? C.line : C.acc })
                .onClick(() => {
                  this.goOnline();
                })

              Text(t('离线'))
                .fontSize(11)
                .fontColor(appStore.offline ? C.onAcc : C.tx2)
                .textAlign(TextAlign.Center)
                .width(56)
                .height(28)
                .backgroundColor(appStore.offline ? C.acc : C.bg2)
                .borderRadius(8)
                .border({ width: 1, color: appStore.offline ? C.acc : C.line })
                .onClick(() => {
                  this.goOffline();
                })
            }
            .width('100%')
            .padding({ top: 11, bottom: 11 })
            .alignItems(VerticalAlign.Center)
            .border({ width: { bottom: 1 }, color: C.line })

            if (!appStore.offline) {
              NavRow({ glyph: 'server', title: t('连接服务器'), sub: t(`${this.serverCount} 个服务器 · 当前 ${this.connText}`), onTap: () => {
                this.go('server');
              } })
            }
            ToggleRow({
              glyph: 'sync',
              title: t('进度同步'),
              sub: this.autoSync ? t('自动 · 读完一章即上报') : t('已暂停 · 进度只记在本机'),
              isOn: this.autoSync,
              onSwitch: (value: boolean) => {
                this.autoSync = value;
              }
            })
            NavRow({ glyph: 'clock', title: t('离线会话补报'), sub: this.outboxLabel, onTap: () => {
              if (!appStore.offline) {
                this.onOpenTab(2);
              }
            } })
          }
          .width('100%')
          .padding({ left: 13, right: 13 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          GroupHead({ title: t('内容') })
          Column() {
            NavRow({ glyph: 'bookmark', title: t('批注与书签'), sub: appStore.offline ? t('离线模式不可用') : t('按书归集 · 进页汇总'), onTap: () => {
              if (!appStore.offline) {
                this.go('annotations');
              }
            } })
            NavRow({ glyph: 'collection', title: t('系列合集'), sub: this.collectionLabel, onTap: () => {
              if (!appStore.offline) {
                this.go('collections');
              }
            } })
            NavRow({ glyph: 'readlist', title: t('书单'), sub: this.listLabel, onTap: () => {
              if (!appStore.offline) {
                this.go('readlists');
              }
            } })
          }
          .width('100%')
          .padding({ left: 13, right: 13 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          GroupHead({ title: t('偏好') })
          Column() {
            NavRow({ glyph: 'type', title: t('阅读偏好'), sub: t('漫画四模式 / 电子书排版'), onTap: () => {
              this.go('prefs');
            } })
            NavRow({ glyph: 'sun', title: t('外观主题'), sub: t('深色与浅色，与网页版一致'), right: this.themeLabel, onTap: () => {
              this.pickTheme();
            } })
            NavRow({ glyph: 'type', title: t('界面语言'), sub: '简体中文 / English / 日本語', right: Lang.tag(), onTap: () => {
              this.pickLang();
            } })
            ToggleRow({
              glyph: 'wifiOff',
              title: t('仅 WiFi 下载'),
              sub: t('公网下自动暂停离线下载'),
              isOn: this.wifiOnly,
              onSwitch: (value: boolean) => {
                this.wifiOnly = value;
                Prefs.putBool('wifiOnly', value);
              }
            })
            ToggleRow({
              glyph: 'eyeOff',
              title: t('隐身阅读'),
              sub: t('不写进度、不计时长、不落统计'),
              isOn: this.incognito,
              onSwitch: (value: boolean) => {
                this.incognito = value;
              }
            })
          }
          .width('100%')
          .padding({ left: 13, right: 13 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          GroupHead({ title: t('关于') })
          Column() {
            NavRow({ glyph: 'info', title: t('关于兰台阅读'), sub: t('版本信息与分发说明'), right: this.version, onTap: () => {
              this.about.open();
            } })
            if (!appStore.offline) {
              NavRow({
                glyph: 'sync',
                title: t('检查更新'),
                sub: this.updateLabel.length > 0 ? this.updateLabel : t('读取 Git 仓库的最新 release'),
                onTap: () => {
                  this.checkUpdate();
                }
              })
              NavRow({ glyph: 'server', title: t('更新源'), sub: this.repoDraft, right: t('编辑'), onTap: () => {
                this.editingRepo = !this.editingRepo;
              } })
              if (this.editingRepo) {
                this.repoEditor()
              }
            }
          }
          .width('100%')
          .padding({ left: 13, right: 13 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          Row({ space: 10 }) {
            if (appStore.offline) {
              ActionBtn({ label: t('返回登录页'), glyph: 'back', onTap: () => {
                this.backToLogin();
              } })
            } else {
              ActionBtn({ label: t('退出登录'), danger: true, glyph: 'close', onTap: () => {
                this.logout();
              } })
            }
          }
          .width('100%')
          .margin({ top: 18 })

          Blank().height(28)
        }
        .width('100%')
        .padding({ left: S.page, right: S.page, bottom: 100 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
