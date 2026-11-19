import { C, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { CoverImage } from '../components/CoverImage';
import { ProgressBar } from '../components/StateViews';
import { ActionBtn, GroupHead, ScreenHead, SegBar } from '../components/Shell';
import { GlyphIcon } from '../components/Icon';
import { JobRow, OfflineBookRow, offlineDb } from '../data/OfflineDb';
import { downloader } from '../net/OfflineDownloader';
import { offlineCache } from '../net/OfflineCache';
import { progressOutbox } from '../net/ProgressOutbox';
import { readingTracker } from '../net/ReadingSession';
import { orphanSweep, SweepReport } from '../net/OrphanSweep';
import { backgroundTask } from '../net/BackgroundTask';
import { appStore } from '../model/AppStore';
import { promptAction } from '@kit.ArkUI';

import { t } from '../common/I18n';
@Component
struct StatLine {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop glyph: string;
  @Prop label: string;
  @Prop value: string;

  build() {
    Row({ space: 11 }) {
      Stack() {
        if (this.glyph.length > 0 && this.glyph.charCodeAt(0) < 128) {
          GlyphIcon({ glyphName: this.glyph, glyphSize: 15, glyphColor: C.tx2 })
        } else {
          Text(this.glyph)
            .fontSize(10.5)
            .fontColor(C.tx2)
        }
      }
      .width(30)
      .height(30)
      .backgroundColor(C.bg3)
      .borderRadius(8)
      Column({ space: 2 }) {
        Text(this.label)
          .fontSize(12.5)
          .fontColor(C.tx)
          .width('100%')
        Text(this.value)
          .fontSize(10)
          .fontColor(C.tx4)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
    .alignItems(VerticalAlign.Center)
  }
}

@Component
export struct DownloadsPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State tab: number = 0;
  @State jobs: JobRow[] = [];
  @State books: OfflineBookRow[] = [];
  @State queued: number = 0;
  @State sessions: number = 0;
  @State orphans: string[] = [];
  @State sweeping: boolean = false;
  @State busy: boolean = false;
  private timer: number = -1;
  private listener: () => void = () => {
    this.reload();
  };

  aboutToAppear(): void {
    downloader.on(this.listener);
    this.reload();
    this.sweep();
    this.timer = setInterval(() => {
      this.reload();
    }, 1200);
    downloader.pump();
  }

  aboutToDisappear(): void {
    downloader.off(this.listener);
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private async reload(): Promise<void> {
    try {
      this.jobs = await offlineDb.jobs();
      this.books = await offlineDb.books();
      this.queued = await progressOutbox.count();
      this.sessions = await readingTracker.pendingCount();
    } catch (error) {
    }
    this.busy = backgroundTask.active();
  }

  private async sweep(): Promise<void> {
    if (this.sweeping) {
      return;
    }
    this.sweeping = true;
    const report: SweepReport = await orphanSweep.run(appStore.session, appStore.api, false);
    this.orphans = report.offlineIds;
    this.sweeping = false;
    if (report.books > 0) {
      promptAction.showToast({ message: t(`${report.books} 本书已从兰台移除，其会话与进度已丢弃`) });
    }
  }

  private async purgeOrphans(): Promise<void> {
    if (this.orphans.length === 0) {
      return;
    }
    const ids: string[] = this.orphans.slice();
    for (let index = 0; index < ids.length; index++) {
      await downloader.remove(ids[index]);
    }
    this.orphans = [];
    await this.reload();
    promptAction.showToast({ message: t(`已清理 ${ids.length} 本失效副本`) });
  }

  private running(): JobRow[] {
    return this.jobs.filter((row: JobRow) => {
      return row.state === 'RUNNING' || row.state === 'PENDING' || row.state === 'PAUSED';
    });
  }

  private done(): JobRow[] {
    return this.jobs.filter((row: JobRow) => {
      return row.state === 'DONE';
    });
  }

  private failed(): JobRow[] {
    return this.jobs.filter((row: JobRow) => {
      return row.state === 'FAILED';
    });
  }

  private rows(): JobRow[] {
    if (this.tab === 0) {
      return this.running();
    }
    return this.tab === 1 ? this.done() : this.failed();
  }

  private tabs(): string[] {
    return [t(`进行中 ${this.running().length}`), t(`已完成 ${this.done().length}`), t(`失败 ${this.failed().length}`)];
  }

  private totalBytes(): number {
    let total: number = 0;
    for (let index = 0; index < this.books.length; index++) {
      total += this.books[index].bytes;
    }
    return total;
  }

  private subtitle(row: JobRow): string {
    if (row.state === 'DONE') {
      const size: number = offlineCache.sizeOf(row.bookId);
      return t(`${row.total} 项 · ${F.bytes(size > 0 ? size : row.bytes)} · ${F.ago(new Date(row.at).toISOString())}完成`);
    }
    if (row.state === 'FAILED') {
      return row.msg.length > 0 ? row.msg : t('下载失败');
    }
    if (row.state === 'PAUSED') {
      return t(`${row.done} / ${row.total} 项 · ${F.bytes(row.bytes)} · ${row.msg}`);
    }
    if (row.state === 'PENDING') {
      return t('排队中 · 等待前一项完成');
    }
    const percent: number = F.percent(row.done, row.total);
    return t(`${row.done} / ${row.total} 项 · ${F.bytes(row.bytes)} · ${percent}%`);
  }

  private percentOf(row: JobRow): number {
    return row.state === 'DONE' ? 100 : F.percent(row.done, row.total);
  }

  private async primary(row: JobRow): Promise<void> {
    if (row.state === 'RUNNING' || row.state === 'PENDING') {
      await downloader.pause(row.bookId);
      return;
    }
    if (row.state === 'PAUSED' || row.state === 'FAILED') {
      await downloader.resume(row.bookId);
    }
  }

  @Builder
  dlRow(row: JobRow) {
    Row({ space: 12 }) {
      CoverImage({ bookId: row.bookId, title: row.title.substring(0, 1), coverWidth: 44, coverHeight: 62, radius: 4 })

      Column({ space: 4 }) {
        Text(row.title)
          .fontSize(12.5)
          .fontColor(C.tx)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.subtitle(row))
          .fontSize(9.5)
          .fontColor(row.state === 'FAILED' ? C.acc : C.tx4)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.orphans.indexOf(row.bookId) >= 0) {
          Text(t('云端已移除'))
            .fontSize(9)
            .fontColor(C.bad)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .border({ width: 1, color: C.bad })
            .borderRadius(3)
        }
        if (row.state !== 'DONE') {
          ProgressBar({ percent: this.percentOf(row) })
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (row.state !== 'DONE') {
        Text(row.state === 'PAUSED' || row.state === 'FAILED' ? t('续') : t('暂'))
          .fontSize(11)
          .fontColor(C.tx2)
          .textAlign(TextAlign.Center)
          .width(28)
          .height(28)
          .backgroundColor(C.bg2)
          .borderRadius(8)
          .border({ width: 1, color: C.line })
          .onClick(() => {
            this.primary(row);
          })
      }

      Row() {
        GlyphIcon({ glyphName: 'trash', glyphSize: 15, glyphColor: C.tx4 })
      }
      .width(26)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        downloader.remove(row.bookId);
      })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  emptyCard(text: string) {
    Column({ space: 6 }) {
      GlyphIcon({ glyphName: 'download', glyphSize: 22, glyphColor: C.tx4 })
      Text(text)
        .fontSize(11.5)
        .fontColor(C.tx4)
    }
    .width('100%')
    .padding({ top: 26, bottom: 26 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .margin({ top: 12 })
  }

  build() {
    Column() {
      ScreenHead({
        title: t('下载队列'),
        sub: t('离线副本'),
        back: t('我的'),
        onBack: () => {
          this.nav.pop();
        }
      })

      Scroll() {
        Column() {
          SegBar({
            options: this.tabs(),
            current: this.tab,
            onPick: (index: number) => {
              this.tab = index;
            }
          })

          if (this.rows().length === 0) {
            this.emptyCard(this.tab === 0 ? t('没有正在下载的任务') : (this.tab === 1 ? t('还没有离线副本') : t('没有失败的下载')))
          } else {
            Column() {
              ForEach(this.rows(), (row: JobRow) => {
                this.dlRow(row)
              }, (row: JobRow) => `${row.bookId}-${row.state}-${row.done}-${row.at}`)
            }
            .width('100%')
            .padding({ left: 13, right: 13 })
            .backgroundColor(C.bg1)
            .borderRadius(R.m)
            .border({ width: 1, color: C.line })
            .margin({ top: 12 })
          }

          if (this.orphans.length > 0) {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Text(t(`${this.orphans.length} 本离线副本已从兰台移除`))
                  .fontSize(11.5)
                  .fontColor(C.tx)
                  .width('100%')
                Text(t('清理只删本机副本与索引，不影响云端'))
                  .fontSize(9.5)
                  .fontColor(C.tx4)
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text(t('清理'))
                .fontSize(10.5)
                .fontColor(C.bad)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(C.bg2)
                .borderRadius(7)
                .border({ width: 1, color: C.bad })
                .onClick(() => {
                  this.purgeOrphans();
                })
            }
            .width('100%')
            .padding(12)
            .backgroundColor(C.bg1)
            .borderRadius(R.m)
            .border({ width: 1, color: C.bad })
            .margin({ top: 12 })
          }

          GroupHead({ title: t('离线存储') })
          Column() {
            StatLine({ glyph: 'download', label: t('离线占用'), value: t(`${F.bytes(this.totalBytes())} · ${this.books.length} 本`) })
            StatLine({ glyph: 'upload', label: t('长时任务'), value: this.busy ? t('下载中 · 后台保持') : t('空闲') })
            StatLine({ glyph: 'clock', label: t('待补报会话'), value: this.sessions > 0 ? t(`${this.sessions} 条 · 联网后自动上报`) : t('无积压') })
            StatLine({ glyph: 'sync', label: t('待补传进度'), value: this.queued > 0 ? t(`${this.queued} 条 · 联网后自动上报`) : t('无积压') })
          }
          .width('100%')
          .padding({ left: 13, right: 13 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          Row({ space: 10 }) {
            ActionBtn({
              label: t('全部暂停'), glyph: 'pause', onTap: () => {
                downloader.pauseAll();
              }
            })
            ActionBtn({
              label: t('清除已完成'), glyph: 'trash', danger: true, onTap: () => {
                downloader.clearDone();
              }
            })
          }
          .width('100%')
          .margin({ top: 12 })

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
