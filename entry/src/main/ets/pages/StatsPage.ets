import { C, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { ActionBtn, GroupHead, NoteCard, Pill, ScreenHead, ToggleRow } from '../components/Shell';
import { EmptyView, ErrorView, LoadingView, ProgressBar } from '../components/StateViews';
import { appStore } from '../model/AppStore';
import { Prefs, PrefKeys } from '../model/Prefs';
import { BookItem, BookStat, DayStat, ReadingStats } from '../model/LantaiModels';
import { progressOutbox, FlushReport } from '../net/ProgressOutbox';
import { readingTracker, SessionFlushReport } from '../net/ReadingSession';
import { orphanSweep, SweepReport } from '../net/OrphanSweep';

import { t } from '../common/I18n';
interface Metric {
  value: string;
  unit: string;
  label: string;
}

interface BarItem {
  date: string;
  label: string;
  ratio: number;
  today: boolean;
}

interface RankRow {
  bookId: string;
  title: string;
  meta: string;
  percent: number;
  book: BookItem | null;
}

function emptyMetrics(): Metric[] {
  return [
    { value: '—', unit: '', label: t('总时长') },
    { value: '—', unit: '', label: t('翻页数') },
    { value: '—', unit: '', label: t('读过的书') }
  ];
}

const WEEK_LABEL: string[] = ['日', '一', '二', '三', '四', '五', '六'];

@Component
export struct StatsPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State incognito: boolean = false;
  @State loading: boolean = true;
  @State error: string = '';
  @State metrics: Metric[] = emptyMetrics();
  @State rangeText: string = '';
  @State bars: BarItem[] = [];
  @State peakText: string = '';
  @State rank: RankRow[] = [];
  @State sessions: number = 0;
  @State progress: number = 0;
  @State lastSyncAt: number = 0;
  @State syncPhase: string = 'idle';
  @State syncDone: number = 0;
  @State syncTotal: number = 0;
  @State syncSent: number = 0;
  @State syncDropped: number = 0;
  @State syncFailed: number = 0;
  @State syncRemain: number = 0;
  @State sweepNote: string = '';
  @State ranksLoading: boolean = false;

  aboutToAppear(): void {
    const stamp: string = Prefs.read(PrefKeys.syncAt);
    this.lastSyncAt = stamp.length > 0 ? parseInt(stamp, 10) : 0;
    this.reload();
  }

  private weekOf(date: string): string {
    const parts: string[] = date.split('-');
    if (parts.length !== 3) {
      return '';
    }
    const stamp: Date = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
    return t(WEEK_LABEL[stamp.getDay()]);
  }

  private thousands(value: number): string {
    const text: string = `${Math.floor(value)}`;
    let out: string = '';
    for (let index = 0; index < text.length; index++) {
      const rest: number = text.length - index;
      out += text.charAt(index);
      if (rest > 1 && rest % 3 === 1) {
        out += ',';
      }
    }
    return out;
  }

  private applyStats(stats: ReadingStats): void {
    const hours: number = Math.floor(stats.totalDurationMs / 3600000);
    const minutes: number = Math.floor(stats.totalDurationMs / 60000) % 60;
    this.metrics = [
      {
        value: hours > 0 ? `${hours}` : `${Math.floor(stats.totalDurationMs / 60000)}`,
        unit: hours > 0 ? `h ${minutes}m` : 'm',
        label: t('总时长')
      },
      { value: this.thousands(stats.totalPagesRead), unit: '', label: t('翻页数') },
      { value: `${stats.bookCount}`, unit: '', label: t('读过的书') }
    ];
    this.rangeText = stats.from.length > 0 && stats.to.length > 0
      ? t(`${stats.from.substring(0, 10)} ~ ${stats.to.substring(0, 10)} · ${stats.sessionCount} 次会话`)
      : t(`${stats.sessionCount} 次会话`);

    const days: DayStat[] = stats.days.slice();
    let peak: number = 0;
    let total: number = 0;
    for (let index = 0; index < days.length; index++) {
      peak = Math.max(peak, days[index].durationMs);
      total += days[index].durationMs;
    }
    const items: BarItem[] = [];
    const lastDate: string = days.length > 0 ? days[days.length - 1].date.substring(0, 10) : '';
    for (let index = 0; index < days.length; index++) {
      const date: string = days[index].date.substring(0, 10);
      items.push({
        date: date,
        label: this.weekOf(date),
        ratio: peak > 0 ? days[index].durationMs / peak : 0,
        today: date === lastDate
      });
    }
    this.bars = items;
    this.peakText = days.length > 0
      ? t(`最高 ${Math.round(peak / 60000)} 分钟 · 日均 ${Math.round(total / days.length / 60000)} 分钟`)
      : t('近 7 天没有阅读记录');
  }

  private async loadRank(stats: ReadingStats): Promise<void> {
    const sorted: BookStat[] = stats.books.slice().sort((left: BookStat, right: BookStat) => right.durationMs - left.durationMs);
    const head: BookStat[] = sorted.slice(0, 5);
    const peak: number = head.length > 0 ? head[0].durationMs : 0;
    const rows: RankRow[] = [];
    for (let index = 0; index < head.length; index++) {
      rows.push({
        bookId: head[index].bookId,
        title: '',
        meta: t(`${F.shortDuration(head[index].durationMs)} · ${head[index].pagesRead} 页 · ${head[index].sessionCount} 次`),
        percent: peak > 0 ? Math.round(head[index].durationMs / peak * 100) : 0,
        book: null
      });
    }
    this.rank = rows;
    if (head.length === 0) {
      return;
    }
    this.ranksLoading = true;
    const filled: RankRow[] = [];
    for (let index = 0; index < head.length; index++) {
      const row: RankRow = rows[index];
      try {
        const detail: BookItem = await appStore.api.book(head[index].bookId);
        row.title = detail.title;
        row.book = detail;
      } catch (error) {
        continue;
      }
      filled.push(row);
    }
    this.rank = filled;
    this.ranksLoading = false;
  }

  private async reload(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const stats: ReadingStats = await appStore.api.readingStats();
      this.applyStats(stats);
      await this.refreshCounts();
      this.loading = false;
      await this.loadRank(stats);
    } catch (error) {
      this.error = (error as Error).message;
      this.metrics = emptyMetrics();
      this.bars = [];
      this.rank = [];
      this.loading = false;
    }
  }

  private async refreshStats(): Promise<void> {
    try {
      const stats: ReadingStats = await appStore.api.readingStats();
      this.applyStats(stats);
      await this.loadRank(stats);
    } catch (error) {
    }
  }

  private async refreshCounts(): Promise<void> {
    this.sessions = await readingTracker.pendingCount();
    this.progress = await progressOutbox.count();
  }

  private busy(): boolean {
    return this.syncPhase === 'detect' || this.syncPhase === 'upload';
  }

  private syncLabel(): string {
    if (this.syncPhase === 'detect') {
      return t('检测中…');
    }
    if (this.syncPhase === 'upload') {
      return t('上报中…');
    }
    if (this.syncPhase === 'done') {
      return t('已同步');
    }
    if (this.syncPhase === 'fail') {
      return t('重试同步');
    }
    return t('立即同步');
  }

  private syncPercent(): number {
    if (this.syncPhase === 'done') {
      return 100;
    }
    if (this.syncTotal <= 0) {
      return this.syncPhase === 'upload' ? 40 : 0;
    }
    return Math.min(100, Math.round(this.syncDone / this.syncTotal * 100));
  }

  private syncText(): string {
    if (this.syncPhase === 'detect') {
      return t('核对书架中已移除的书籍…');
    }
    if (this.syncPhase === 'upload') {
      return this.syncTotal > 0 ? t(`上报 ${this.syncDone} / ${this.syncTotal} 条`) : t('正在上报…');
    }
    if (this.syncPhase === 'done') {
      let text: string = t(`成功 ${this.syncSent} 条`);
      if (this.syncDropped > 0) {
        text += t(` · 丢弃 ${this.syncDropped} 条`);
      }
      return text;
    }
    if (this.syncPhase === 'fail') {
      return t(`未完成 · 仍积压 ${this.syncRemain} 条`);
    }
    return '';
  }

  private lastSyncText(): string {
    if (this.lastSyncAt <= 0) {
      return t('尚未同步');
    }
    return `${t('上次同步')} · ${F.ago(new Date(this.lastSyncAt).toISOString())}`;
  }

  private async syncNow(): Promise<void> {
    if (this.busy()) {
      return;
    }
    await this.refreshCounts();
    this.syncTotal = this.sessions + this.progress;
    this.syncDone = 0;
    this.syncSent = 0;
    this.syncDropped = 0;
    this.syncFailed = 0;
    this.syncRemain = this.syncTotal;
    this.sweepNote = '';
    const session = appStore.session;
    if (!session.ready()) {
      this.syncPhase = 'fail';
      return;
    }
    this.syncPhase = 'detect';
    const sweep: SweepReport = await orphanSweep.run(session, appStore.api);
    if (sweep.failed) {
      this.sweepNote = t('失效检测未完成，本轮只上报未失效的数据');
    } else if (sweep.books > 0) {
      this.sweepNote = t(`${sweep.books} 本书已从兰台移除：丢弃会话 ${sweep.sessions} 条、进度 ${sweep.progress} 条、离线副本 ${sweep.offline} 本待清理`);
      this.syncDropped += sweep.sessions + sweep.progress;
    }
    await this.refreshCounts();
    this.syncTotal = this.sessions + this.progress;
    this.syncPhase = 'upload';
    const sessionReport: SessionFlushReport = await readingTracker.flush(session, (done: number) => {
      this.syncDone = done;
    });
    this.syncSent += sessionReport.sent;
    this.syncDropped += sessionReport.dropped;
    this.syncFailed += sessionReport.failed;
    const base: number = sessionReport.sent + sessionReport.dropped;
    const progressReport: FlushReport = await progressOutbox.flush(session, (done: number) => {
      this.syncDone = base + done;
    });
    this.syncSent += progressReport.sent;
    this.syncDropped += progressReport.dropped;
    this.syncFailed += progressReport.failed;
    await this.refreshCounts();
    this.syncRemain = this.sessions + this.progress;
    this.syncDone = this.syncSent + this.syncDropped;
    if (this.syncRemain > 0) {
      this.syncPhase = 'fail';
      return;
    }
    this.syncPhase = 'done';
    this.lastSyncAt = Date.now();
    await Prefs.write(PrefKeys.syncAt, `${this.lastSyncAt}`);
    await this.refreshStats();
    setTimeout(() => {
      if (this.syncPhase === 'done') {
        this.syncPhase = 'idle';
      }
    }, 4000);
  }

  private async detectNow(): Promise<void> {
    if (this.busy()) {
      return;
    }
    this.syncPhase = 'detect';
    this.syncSent = 0;
    this.syncDropped = 0;
    this.syncDone = 0;
    this.syncTotal = 0;
    this.sweepNote = '';
    const sweep: SweepReport = await orphanSweep.run(appStore.session, appStore.api);
    await this.refreshCounts();
    this.syncRemain = this.sessions + this.progress;
    if (sweep.failed) {
      this.syncPhase = 'fail';
      this.sweepNote = t('检测失败，请检查网络后重试');
      return;
    }
    if (sweep.books > 0) {
      this.syncDropped = sweep.sessions + sweep.progress;
      this.sweepNote = t(`${sweep.books} 本书已从兰台移除：丢弃会话 ${sweep.sessions} 条、进度 ${sweep.progress} 条、离线副本 ${sweep.offline} 本待清理`);
    } else {
      this.sweepNote = t('没有发现失效书籍');
    }
    this.syncPhase = 'done';
    await this.refreshStats();
    setTimeout(() => {
      if (this.syncPhase === 'done') {
        this.syncPhase = 'idle';
      }
    }, 4000);
  }

  private openBook(row: RankRow): void {
    if (row.book === null) {
      return;
    }
    appStore.selected = row.book;
    this.nav.pushPathByName('book', null);
  }

  @Builder
  metricsCard() {
    Row() {
      ForEach(this.metrics, (item: Metric, index: number) => {
        Column({ space: 3 }) {
          Row() {
            Text(item.value)
              .fontSize(19)
              .fontColor(C.acc2)
            if (item.unit.length > 0) {
              Text(item.unit)
                .fontSize(10)
                .fontColor(C.acc2)
                .margin({ left: 2 })
            }
          }
          .alignItems(VerticalAlign.Bottom)

          Text(item.label)
            .fontSize(10)
            .fontColor(C.tx4)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .border({ width: { right: index === this.metrics.length - 1 ? 0 : 1 }, color: C.line })
      }, (item: Metric) => `${item.label}-${item.value}-${item.unit}`)
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
  }

  @Builder
  barsCard() {
    Column() {
      Row({ space: 7 }) {
        ForEach(this.bars, (item: BarItem, index: number) => {
          Column() {
            Blank()
            Column()
              .width('100%')
              .height(Math.max(4, item.ratio * 84))
              .backgroundColor(item.today ? C.acc : C.bg4)
              .borderRadius(3)
            Text(item.label)
              .fontSize(9)
              .fontColor(item.today ? C.acc2 : C.tx4)
              .margin({ top: 6 })
          }
          .layoutWeight(1)
          .height(106)
        }, (item: BarItem) => `${item.date}-${Math.round(item.ratio * 1000)}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Text(this.peakText)
        .fontSize(9.5)
        .fontColor(C.tx4)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 16, bottom: 12 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
  }

  @Builder
  rankCard() {
    Column() {
      ForEach(this.rank, (item: RankRow, index: number) => {
        Row({ space: 11 }) {
          Text(`${index + 1}`)
            .fontSize(11)
            .fontColor(C.acc2)
            .width(14)
          Column({ space: 2 }) {
            Text(item.title.length > 0 ? item.title : t('读取中…'))
              .fontSize(12.5)
              .fontColor(item.title.length > 0 ? C.tx : C.tx4)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(item.meta)
              .fontSize(10)
              .fontColor(C.tx4)
              .maxLines(1)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column() {
            Row()
              .width(`${item.percent}%`)
              .height(3)
              .backgroundColor(C.acc)
              .borderRadius(2)
          }
          .width(58)
          .height(3)
          .backgroundColor(C.bg4)
          .borderRadius(2)
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        .onClick(() => {
          this.openBook(item);
        })
      }, (item: RankRow) => `${item.bookId}-${item.title}`)
    }
    .width('100%')
    .padding({ left: 13, right: 13 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
  }

  @Builder
  syncCard() {
    Column() {
      Row({ space: 11 }) {
        Text(t('会'))
          .fontSize(10.5)
          .fontColor(C.tx2)
          .textAlign(TextAlign.Center)
          .width(30)
          .height(30)
          .backgroundColor(C.bg3)
          .borderRadius(8)
        Column({ space: 2 }) {
          Text(t('离线会话待补报')).fontSize(12.5).fontColor(C.tx).width('100%')
          Text(this.sessions > 0 ? t(`${this.sessions} 条 · 联网后自动上报`) : t('无积压'))
            .fontSize(10).fontColor(C.tx4).width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Pill({ label: this.sessions > 0 ? t('待同步') : t('已同步'), tone: this.sessions > 0 ? 'warn' : 'done' })
      }
      .width('100%')
      .padding({ top: 11, bottom: 11 })
      .alignItems(VerticalAlign.Center)

      Row({ space: 11 }) {
        Text(t('进'))
          .fontSize(10.5)
          .fontColor(C.tx2)
          .textAlign(TextAlign.Center)
          .width(30)
          .height(30)
          .backgroundColor(C.bg3)
          .borderRadius(8)
        Column({ space: 2 }) {
          Text(t('进度补报')).fontSize(12.5).fontColor(C.tx).width('100%')
          Text(this.progress > 0 ? t(`${this.progress} 条 · 断网时暂存本机`) : t('无积压'))
            .fontSize(10).fontColor(C.tx4).width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Pill({ label: this.progress > 0 ? t('待同步') : t('已同步'), tone: this.progress > 0 ? 'warn' : 'done' })
      }
      .width('100%')
      .padding({ top: 11, bottom: 11 })
      .alignItems(VerticalAlign.Center)

      Row({ space: 11 }) {
        Text(t('幂'))
          .fontSize(10.5)
          .fontColor(C.tx2)
          .textAlign(TextAlign.Center)
          .width(30)
          .height(30)
          .backgroundColor(C.bg3)
          .borderRadius(8)
        Column({ space: 2 }) {
          Text(t('幂等去重')).fontSize(12.5).fontColor(C.tx).width('100%')
          Text(t('同一会话重发不会重复计时')).fontSize(10).fontColor(C.tx4).maxLines(1).width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Pill({ label: t('已启用'), tone: 'done' })
      }
      .width('100%')
      .padding({ top: 11, bottom: 11 })
      .alignItems(VerticalAlign.Center)

      Text(this.lastSyncText())
        .fontSize(9.5)
        .fontColor(C.tx4)
        .width('100%')
        .padding({ bottom: 9 })

      ToggleRow({
        glyph: 'eyeOff',
        title: t('隐身阅读'),
        sub: t('该时段不写进度、不计时长'),
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
  }

  @Builder
  syncPanel() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.syncLabel())
          .fontSize(10.5)
          .fontColor(this.syncPhase === 'fail' ? C.bad : (this.syncPhase === 'done' ? C.ok : C.acc2))
          .layoutWeight(1)
        if (this.syncPhase === 'upload') {
          Text(`${this.syncPercent()}%`)
            .fontSize(10)
            .fontColor(C.acc2)
        }
      }
      .width('100%')

      if (this.syncPhase === 'upload' || this.syncPhase === 'done') {
        ProgressBar({ percent: this.syncPercent(), barHeight: 3 })
      }

      Text(this.syncText())
        .fontSize(10)
        .fontColor(C.tx3)
        .width('100%')
        .maxLines(2)

      if (this.syncPhase === 'fail') {
        Text(t('检查网络或登录状态后重试'))
          .fontSize(9.5)
          .fontColor(C.bad)
          .width('100%')
      }

      if (this.sweepNote.length > 0) {
        Text(this.sweepNote)
          .fontSize(9.5)
          .fontColor(C.tx4)
          .width('100%')
          .maxLines(3)
      }
    }
    .width('100%')
    .padding({ left: 13, right: 13, top: 11, bottom: 11 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: this.syncPhase === 'fail' ? C.bad : C.line })
    .margin({ top: 10 })
  }

  build() {
    Column() {
      ScreenHead({ title: t('阅读统计'), sub: t('时长只来自心跳 · 页数只来自翻页'), titleSize: 18 })

      Scroll() {
        Column() {
          if (this.loading) {
            Column() {
              LoadingView({ label: t('汇总阅读统计') })
            }
            .width('100%')
            .height(300)
          } else if (this.error.length > 0) {
            Column() {
              ErrorView({ message: this.error, onRetry: () => {
                this.reload();
              } })
            }
            .width('100%')
            .height(300)
          } else {
            Row({ space: 6 }) {
              Pill({ label: t('近 30 天'), tone: 'acc' })
              Text(this.rangeText)
                .fontSize(10)
                .fontColor(C.tx4)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')

            Column() {
              this.metricsCard()
            }
            .margin({ top: 12 })

            GroupHead({ title: t('每日时长'), meta: t('分钟') })
            if (this.bars.length > 0) {
              this.barsCard()
            } else {
              Column() {
                EmptyView({ title: t('还没有阅读记录'), hint: t('读几页书，这里会出现每日时长'), glyph: 'clock' })
              }
              .width('100%')
              .height(180)
            }

            GroupHead({ title: t('按书排行'), meta: this.ranksLoading ? t('加载书名') : '' })
            if (this.rank.length > 0) {
              this.rankCard()
            } else {
              Column() {
                EmptyView({ title: t('近 30 天没有读完的会话'), hint: t('翻页与时长都记在服务端'), glyph: 'book' })
              }
              .width('100%')
              .height(180)
            }

            GroupHead({ title: t('同步与离线') })
            this.syncCard()

            Row({ space: 10 }) {
              ActionBtn({
                label: this.syncLabel(),
                glyph: 'sync',
                onTap: () => {
                  this.syncNow();
                }
              })
              ActionBtn({
                label: t('检测失效'),
                glyph: 'search',
                onTap: () => {
                  this.detectNow();
                }
              })
            }
            .width('100%')
            .margin({ top: 12 })

            if (this.syncPhase !== 'idle') {
              this.syncPanel()
            }

            NoteCard({ text: t('统计只认服务端 reading/stats 的聚合结果；该接口固定返回近 30 天，页面不再提供其它区间。离线产生的会话先落本机队列，联网后按幂等键补报，不会重复计时。同步前会先核对书籍是否仍在兰台，已移除书籍的会话、进度与离线副本直接丢弃。') })

            Blank().height(28)
          }
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
