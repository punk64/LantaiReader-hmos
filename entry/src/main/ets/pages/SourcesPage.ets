import { promptAction } from '@kit.ArkUI';
import { C, FT, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { GroupHead, NoteCard, Pill, ScreenHead } from '../components/Shell';
import { appStore } from '../model/AppStore';
import { BookPage, BookQuery, emptyQuery } from '../model/LantaiModels';
import { OfflineBookRow, offlineDb } from '../data/OfflineDb';
import { LocalStore } from '../net/LocalStore';
import { CachePurge } from '../net/CachePurge';
import { CacheQuota } from '../net/CacheQuota';
import { CoverCache } from '../components/CoverCache';

import { t } from '../common/I18n';
interface SourceRow {
  glyph: string;
  title: string;
  sub: string;
  count: string;
  tone: string;
  feed: string;
}

interface Legend {
  color: string;
  label: string;
}

@Component
export struct SourcesPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('netTick') @Watch('onNetTick') netTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State connText: string = '';
  @State rows: SourceRow[] = [];
  @State legends: Legend[] = [];
  @State cacheBytes: number = 0;
  @State limitBytes: number = CacheQuota.fallback;
  @State limitInput: string = '';
  @State busy: boolean = false;
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.limitBytes = CacheQuota.limit();
    this.limitInput = F.cap(this.limitBytes);
    this.refreshConn();
    this.reload();
    this.loadCache();
  }

  private refreshConn(): void {
    this.connText = appStore.connectionLabel();
  }

  private onNetTick(): void {
    this.refreshConn();
  }

  private async loadCache(): Promise<void> {
    try {
      this.cacheBytes = await CacheQuota.measure();
    } catch (error) {
      this.cacheBytes = 0;
    }
  }

  private async reload(): Promise<void> {
    this.loading = true;
    let localCount: number = appStore.localMetas.length;
    let localBytes: number = 0;
    for (let index: number = 0; index < appStore.localMetas.length; index++) {
      localBytes += appStore.localMetas[index].sizeBytes;
    }
    let cloudTotal: number = 0;
    try {
      const query: BookQuery = emptyQuery();
      query.size = 1;
      const page: BookPage = await appStore.api.books(query);
      cloudTotal = page.total;
    } catch (error) {
      cloudTotal = 0;
    }
    let offlineCount: number = 0;
    let offlineBytes: number = 0;
    try {
      const books: OfflineBookRow[] = await offlineDb.books();
      offlineCount = books.length;
      for (let index: number = 0; index < books.length; index++) {
        offlineBytes += books[index].bytes;
      }
    } catch (error) {
      offlineCount = 0;
    }
    this.rows = [
      {
        glyph: 'book',
        title: t('本地库'),
        sub: t('应用内副本 · 可移除'),
        count: t(`${localCount} 册`),
        tone: localCount > 0 ? 'acc' : 'mute',
        feed: 'local'
      },
      {
        glyph: 'server',
        title: t('云库'),
        sub: t(`${this.connText} · 已连接`),
        count: t(`${cloudTotal} 册`),
        tone: 'info',
        feed: 'cloud'
      },
      {
        glyph: 'download',
        title: t('离线副本'),
        sub: t('云库下载到本机 · 断网可读'),
        count: t(`${offlineCount} 册`),
        tone: offlineCount > 0 ? 'done' : 'mute',
        feed: 'offline'
      }
    ];
    this.legends = [
      { color: C.acc, label: t(`离线副本 ${F.bytes(offlineBytes)}`) },
      { color: C.bad, label: t(`本机导入 ${F.bytes(localBytes)}`) }
    ];
    this.loading = false;
  }

  private usagePercent(): number {
    if (this.limitBytes <= 0) {
      return 0;
    }
    const ratio: number = this.cacheBytes / this.limitBytes * 100;
    if (ratio >= 100) {
      return 100;
    }
    return Math.max(this.cacheBytes > 0 ? 1 : 0, Math.round(ratio));
  }

  private rootLabel(): string {
    const root: string = appStore.localRoot;
    if (root.length === 0) {
      return t('未记录');
    }
    if (root === 'picked') {
      return t('逐个文件选择导入');
    }
    return root.replace('file://', '');
  }

  private async applyLimit(): Promise<void> {
    const bytes: number = CacheQuota.parse(this.limitInput);
    if (bytes <= 0) {
      promptAction.showToast({ message: t('请输入 256M ~ 64G 的容量，如 4G、512M、1.5G') });
      return;
    }
    if (bytes === this.limitBytes) {
      promptAction.showToast({ message: t('上限未变化') });
      return;
    }
    this.busy = true;
    await CacheQuota.apply(bytes);
    this.limitBytes = CacheQuota.limit();
    this.limitInput = F.cap(this.limitBytes);
    await this.loadCache();
    this.busy = false;
    promptAction.showToast({ message: t(`缓存上限已设为 ${F.cap(this.limitBytes)}`) });
  }

  private async removeAllLocal(): Promise<void> {
    const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: t('移除全部本地书'),
      message: t('将删除本地书索引、阅读进度与应用内副本，并释放占用的空间。授权目录中的原文件不会被删除。'),
      buttons: [
        { text: t('取消'), color: C.tx3 },
        { text: t('移除'), color: C.bad }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    const freed: number = await LocalStore.purgeAll(appStore.localMetas, appStore.localRoot);
    appStore.localBooks = [];
    appStore.localMetas = [];
    appStore.localMissing = [];
    appStore.localRoot = '';
    appStore.localRootStale = false;
    await this.reload();
    promptAction.showToast({ message: t(`已移除全部本地书，释放 ${F.bytes(freed)}`) });
  }

  @Builder
  localCard() {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(appStore.localRootStale ? t('本地库需要重新授权') : t('本地库目录'))
          .fontSize(11)
          .fontColor(appStore.localRootStale ? C.warn : C.tx)
        Text(this.rootLabel())
          .fontSize(9.5)
          .fontColor(C.tx4)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(t('移除全部'))
        .fontSize(10.5)
        .fontColor(C.tx3)
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .backgroundColor(C.bg2)
        .borderRadius(7)
        .onClick(() => {
          this.removeAllLocal();
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .margin({ top: 8 })
  }

  private async purgeCache(): Promise<void> {
    const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: t('清理缓存'),
      message: t('将清空页图与文档副本缓存，原始文件与离线副本不受影响。正在阅读的书会在下次打开时重新解压。'),
      buttons: [
        { text: t('取消'), color: C.tx3 },
        { text: t('清理'), color: C.acc }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    const freed: number = await CachePurge.purge();
    CoverCache.clear();
    await this.loadCache();
    promptAction.showToast({
      message: freed > 0 ? t(`已释放 ${F.bytes(freed)}`) : t('没有可释放的缓存')
    });
  }

  @Builder
  quotaCard() {
    Row({ space: 14 }) {
      Stack() {
        Progress({ value: this.usagePercent(), total: 100, type: ProgressType.Ring })
          .width(78)
          .height(78)
          .color(C.acc)
          .backgroundColor(C.bg4)
          .style({ strokeWidth: 7 })
        Column({ space: 1 }) {
          Text(`${this.usagePercent()}%`)
            .fontSize(15)
            .fontColor(C.acc2)
          Text(t('已用'))
            .fontSize(7.5)
            .fontColor(C.tx4)
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width(78)
      .height(78)

      Column({ space: 5 }) {
        Text(t('缓存'))
          .fontSize(14.5)
          .fontColor(C.tx)
          .letterSpacing(0.5)
        Text(`${F.cap(this.cacheBytes)} / ${F.cap(this.limitBytes)}`)
          .fontSize(16)
          .fontFamily(FT.mono)
          .fontColor(C.tx)
        Text(t('解压页图与文档副本 · 超出上限清理最久未用'))
          .fontSize(9.5)
          .fontColor(C.tx4)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 7 }) {
          TextInput({ text: this.limitInput, placeholder: '4G' })
            .width(70)
            .height(28)
            .fontSize(11)
            .fontFamily(FT.mono)
            .fontColor(C.tx)
            .placeholderColor(C.tx4)
            .textAlign(TextAlign.Center)
            .padding(0)
            .backgroundColor(C.bg2)
            .borderRadius(7)
            .border({ width: 1, color: C.line2 })
            .maxLength(7)
            .enabled(!this.busy)
            .onChange((value: string) => {
              this.limitInput = value;
            })
            .onSubmit(() => {
              this.applyLimit();
            })
          this.actionChipConfirm()
          this.actionChipPurge()
        }
        .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  actionChipConfirm() {
    Text(t('应用'))
      .fontSize(11)
      .fontColor(C.acc2)
      .padding({ left: 11, right: 11, top: 6, bottom: 6 })
      .backgroundColor(C.bg2)
      .borderRadius(7)
      .border({ width: 1, color: C.line2 })
      .opacity(this.busy || this.limitInput.length === 0 ? 0.45 : 1)
      .onClick(() => {
        if (!this.busy) {
          this.applyLimit();
        }
      })
  }

  @Builder
  actionChipPurge() {
    Text(t('清理'))
      .fontSize(11)
      .fontColor(C.tx2)
      .padding({ left: 11, right: 11, top: 6, bottom: 6 })
      .backgroundColor(C.bg2)
      .borderRadius(7)
      .border({ width: 1, color: C.line })
      .opacity(this.busy ? 0.45 : 1)
      .onClick(() => {
        if (!this.busy) {
          this.purgeCache();
        }
      })
  }

  @Builder
  legendRow() {
    Row({ space: 18 }) {
      ForEach(this.legends, (item: Legend) => {
        Row({ space: 5 }) {
          Circle()
            .width(6)
            .height(6)
            .fill(item.color)
          Text(item.label)
            .fontSize(9)
            .fontColor(C.tx4)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }, (item: Legend) => item.label)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 9, bottom: 9 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .margin({ top: 8 })
  }

  build() {
    Column() {
      ScreenHead({
        title: t('来源与存储'),
        sub: t('本地库 / 云库 / 离线副本'),
        back: t('我的'),
        onBack: () => {
          this.nav.pop();
        }
      })

      Scroll() {
        Column() {
          this.quotaCard()
          this.legendRow()
          if (appStore.localMetas.length > 0 || appStore.localBooks.length > 0) {
            this.localCard()
          }

          GroupHead({ title: t('书库来源') })
          Column() {
            if (this.loading) {
              Row() {
                Text(t('读取中…'))
                  .fontSize(11)
                  .fontColor(C.tx4)
              }
              .width('100%')
              .height(72)
              .justifyContent(FlexAlign.Center)
            } else {
              ForEach(this.rows, (item: SourceRow) => {
                Row({ space: 11 }) {
                  Text(item.glyph)
                    .fontSize(10.5)
                    .fontColor(C.tx2)
                    .textAlign(TextAlign.Center)
                    .width(30)
                    .height(30)
                    .backgroundColor(C.bg3)
                    .borderRadius(8)
                  Column({ space: 2 }) {
                    Text(item.title)
                      .fontSize(12.5)
                      .fontColor(C.tx)
                      .width('100%')
                    Text(item.feed === 'cloud' ? `${this.connText} · ${t('已连接')}` : item.sub)
                      .fontSize(10)
                      .fontColor(C.tx4)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Pill({ label: item.count, tone: item.tone })
                }
                .width('100%')
                .padding({ top: 11, bottom: 11 })
                .alignItems(VerticalAlign.Center)
              }, (item: SourceRow) => `${item.title}-${item.count}`)
            }
          }
          .width('100%')
          .padding({ left: 13, right: 13 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          NoteCard({ text: t('原始文件始终只保留一份；缓存可随时清理重建，超出上限时自动覆盖最久未用。') })
            .margin({ top: 14 })

          Blank().height(28)
        }
        .width('100%')
        .padding({ left: S.page, right: S.page })
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
