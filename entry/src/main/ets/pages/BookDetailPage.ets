import { hilog } from '@kit.PerformanceAnalysisKit';
import { C, FT, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { ProgressMarks } from '../common/ProgressMarks';
import { appStore } from '../model/AppStore';
import {
  BookItem,
  BookStat,
  ChapterItem,
  DayStat,
  emptyBook,
  isEbook,
  MEDIA_ERROR,
  profileLabel,
  ReadListRef,
  ReadingStats
} from '../model/LantaiModels';
import { CoverImage } from '../components/CoverImage';
import { CoverViewer } from '../components/CoverViewer';
import { FormatBadge } from '../components/BookViews';
import { ApiError } from '../net/LantaiApi';
import { GlyphIcon } from '../components/Icon';
import { ProgressBar } from '../components/StateViews';
import { ScreenHead } from '../components/Shell';
import { promptAction } from '@kit.ArkUI';
import { downloader } from '../net/OfflineDownloader';
import { offlineCache } from '../net/OfflineCache';
import { offlineDb, OfflineBookRow } from '../data/OfflineDb';

import { t, tf } from '../common/I18n';
function emptyStats(): ReadingStats {
  return {
    from: '',
    to: '',
    totalDurationMs: 0,
    totalPagesRead: 0,
    sessionCount: 0,
    bookCount: 0,
    books: [],
    days: []
  };
}

function charsLabel(count: number): string {
  if (count <= 0) {
    return '';
  }
  if (count < 1000) {
    return t(`${count} 字`);
  }
  return t(`${(count / 1000).toFixed(1)} 千字`);
}

@Component
struct InfoCell {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Column({ space: 1 }) {
      Text(this.label)
        .fontSize(9)
        .fontColor(C.tx4)
        .letterSpacing(0.2)
      Text(this.value.length > 0 ? this.value : '—')
        .fontSize(10.5)
        .fontColor(C.tx2)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }
}

@Component
struct LedgerRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop mono: boolean = false;

  build() {
    Row() {
      Text(this.label)
        .fontSize(11)
        .fontColor(C.tx4)
        .width(74)
      Text(this.value.length > 0 ? this.value : '—')
        .fontSize(11)
        .fontColor(C.tx2)
        .fontFamily(this.mono ? FT.mono : FT.ui)
        .layoutWeight(1)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 7, bottom: 7 })
  }
}

@Component
struct LedgerCell {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop mono: boolean = false;

  build() {
    Column({ space: 1 }) {
      Text(this.label)
        .fontSize(8.5)
        .fontColor(C.tx4)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.value.length > 0 ? this.value : '—')
        .fontSize(10.5)
        .fontColor(C.tx2)
        .fontFamily(this.mono ? FT.mono : FT.ui)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }
}

@Component
struct LedgerLine {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop mono: boolean = false;

  build() {
    Row({ space: 8 }) {
      Text(this.label)
        .fontSize(9.5)
        .fontColor(C.tx4)
        .width(58)
      Text(this.value.length > 0 ? this.value : '—')
        .fontSize(10.5)
        .fontColor(C.tx2)
        .fontFamily(this.mono ? FT.mono : FT.ui)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

@Component
struct ActCell {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop glyph: string = '';
  @Prop label: string = '';
  @Prop active: boolean = false;
  @Prop dimmed: boolean = false;
  onTap: () => void = () => {};

  build() {
    Column({ space: 3 }) {
      GlyphIcon({
        glyphName: this.glyph,
        glyphSize: 16,
        glyphColor: this.active ? C.acc2 : C.tx3
      })
      Text(this.label)
        .fontSize(9.5)
        .fontColor(this.active ? C.acc2 : C.tx3)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.active ? C.accBg : C.bg3)
    .borderRadius(9)
    .border({ width: 1, color: this.active ? C.accLine : C.line })
    .opacity(this.dimmed ? 0.32 : 1)
    .onClick(() => {
      if (!this.dimmed) {
        this.onTap();
      }
    })
  }
}

@Component
struct ChipOp {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop glyph: string = '';
  @Prop label: string = '';
  @Prop active: boolean = false;
  @Prop chevron: string = '';
  onTap: () => void = () => {};

  build() {
    Row({ space: 4 }) {
      GlyphIcon({
        glyphName: this.glyph,
        glyphSize: 11,
        glyphColor: this.active ? C.acc2 : C.tx3
      })
      if (this.label.length > 0) {
        Text(this.label)
          .fontSize(9.5)
          .fontColor(this.active ? C.acc2 : C.tx3)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      if (this.chevron.length > 0) {
        GlyphIcon({
          glyphName: this.chevron,
          glyphSize: 10,
          glyphColor: this.active ? C.acc2 : C.tx4
        })
      }
    }
    .layoutWeight(1)
    .height(22)
    .padding({ left: 4, right: 4 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.active ? C.accBg : C.bg3)
    .borderRadius(7)
    .border({ width: 1, color: this.active ? C.accLine : C.line })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
struct StatCell {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop value: string = '';
  @Prop label: string = '';

  build() {
    Column({ space: 1 }) {
      Text(this.value)
        .fontSize(12)
        .fontColor(C.acc2)
        .fontFamily(FT.disp)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.label)
        .fontSize(9)
        .fontColor(C.tx4)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
struct TocRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop title: string = '';
  @Prop meta: string = '';
  @Prop current: boolean = false;
  onTap: () => void = () => {};

  build() {
    Row({ space: 10 }) {
      Stack() {
        GlyphIcon({ glyphName: 'toc', glyphSize: 14, glyphColor: C.tx3 })
      }
      .width(26)
      .height(26)
      .backgroundColor(C.bg3)
      .borderRadius(8)

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(12.5)
          .fontColor(this.current ? C.acc2 : C.tx)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.meta.length > 0) {
          Text(this.meta)
            .fontSize(10)
            .fontColor(C.tx4)
            .maxLines(1)
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      GlyphIcon({ glyphName: 'next', glyphSize: 13, glyphColor: C.tx4 })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: C.line })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
struct TocNum {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop active: boolean = false;
  @Prop gap: boolean = false;
  onTap: () => void = () => {};

  build() {
    Row() {
      Text(this.label)
        .fontSize(10.5)
        .fontFamily(FT.mono)
        .fontColor(this.active ? C.onAcc : (this.gap ? C.tx4 : C.tx2))
    }
    .height(24)
    .constraintSize({ minWidth: 24 })
    .padding({ left: 5, right: 5 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.active ? C.acc : Color.Transparent)
    .borderRadius(7)
    .onClick(() => {
      if (!this.gap) {
        this.onTap();
      }
    })
  }
}

@Component
struct TocCell {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop current: boolean = false;
  onTap: () => void = () => {};

  build() {
    Column() {
      Text(this.label)
        .fontSize(11)
        .fontFamily(FT.mono)
        .fontColor(this.current ? C.onAcc : C.tx2)
    }
    .width('100%')
    .height(34)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.current ? C.acc : C.bg3)
    .borderRadius(8)
    .border({ width: 1, color: this.current ? C.acc : C.line })
    .onClick(() => {
      this.onTap();
    })
  }
}

@CustomDialog
struct TocSizeDialog {
  controller?: CustomDialogController;
  value: string = '';
  onOk: (value: number) => void = () => {};
  @State text: string = '';

  aboutToAppear(): void {
    this.text = this.value;
  }

  build() {
    Column({ space: 12 }) {
      Text(t('自定义每页数量'))
        .fontSize(13)
        .fontColor(C.tx)
        .width('100%')
      TextInput({ text: this.text, placeholder: t('1 – 500') })
        .type(InputType.Number)
        .fontSize(13)
        .height(38)
        .onChange((value: string) => {
          this.text = value;
        })
      Text(t('范围 1 – 500，超出按边界处理'))
        .fontSize(9.5)
        .fontColor(C.tx4)
        .width('100%')
      Row({ space: 8 }) {
        Text(t('取消'))
          .fontSize(12)
          .fontColor(C.tx2)
          .layoutWeight(1)
          .height(34)
          .textAlign(TextAlign.Center)
          .backgroundColor(C.bg3)
          .borderRadius(9)
          .onClick(() => {
            this.controller?.close();
          })
        Text(t('确定'))
          .fontSize(12)
          .fontColor(C.onAcc)
          .layoutWeight(1)
          .height(34)
          .textAlign(TextAlign.Center)
          .backgroundColor(C.acc)
          .borderRadius(9)
          .onClick(() => {
            const parsed: number = parseInt(this.text, 10);
            if (!isNaN(parsed)) {
              this.onOk(Math.max(1, Math.min(500, parsed)));
            }
            this.controller?.close();
          })
      }
      .width('100%')
    }
    .width('78%')
    .padding(16)
    .backgroundColor(C.bg1)
    .borderRadius(R.l)
    .border({ width: 1, color: C.line })
  }
}

@Component
export struct BookDetailPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('progressVer') @Watch('onMarks') progressVer: number = 0;
  @State marksTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State book: BookItem = emptyBook();
  @State loading: boolean = true;
  @State error: string = '';
  @State chapters: ChapterItem[] = [];
  @State chapterTotal: number = 0;
  @State stats: ReadingStats = emptyStats();
  @State bookStat: BookStat | null = null;
  @State readlists: ReadListRef[] = [];
  @State showInfo: boolean = false;
  @State showSummary: boolean = false;
  @State tocMode: string = 'list';
  private tocPinned: boolean = false;
  @State tocPage: number = 0;
  @State listSize: number = 10;
  @State gridSize: number = 50;
  @State sizeText: string = '';
  @State coverOpen: boolean = false;
  @State wanted: boolean = false;
  @State cached: boolean = false;
  private sizeDialog: CustomDialogController = new CustomDialogController({
    builder: TocSizeDialog({ value: '', onOk: (value: number) => {} }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    const selected: BookItem | null = appStore.selected;
    if (selected !== null) {
      this.book = selected;
    }
    this.tocMode = isEbook(this.book.profile) ? 'list' : 'grid';
    this.load();
  }

  onMarks(): void {
    this.marksTick = this.marksTick + 1;
  }

  private openCover(): void {
    this.coverOpen = true;
    appStore.backHook = () => {
      if (this.coverOpen) {
        this.closeCover();
        return true;
      }
      return false;
    };
  }

  private closeCover(): void {
    this.coverOpen = false;
    appStore.backHook = null;
  }

  private async load(): Promise<void> {
    if (this.book.id.length === 0) {
      this.loading = false;
      this.error = t('未选择书籍');
      return;
    }
    if (appStore.offline) {
      this.cached = true;
      this.loading = false;
      this.error = '';
      return;
    }
    try {
      const detail: BookItem = await appStore.api.book(this.book.id);
      this.book = detail;
      if (!this.tocPinned) {
        this.tocMode = isEbook(detail.profile) ? 'list' : 'grid';
      }
      this.cached = await this.cachedOf(detail.id);
      this.loading = false;
      await this.loadSide(detail.id);
    } catch (error) {
      this.loading = false;
      const status: number = error instanceof ApiError ? error.status : 0;
      this.error = status === 404 || status === 410
        ? t('这本书已在兰台移除，本机副本与进度会同步丢弃')
        : (error as Error).message;
    }
  }

  private async loadSide(id: string): Promise<void> {
    try {
      const toc = await appStore.api.chapters(id);
      this.chapters = toc.items;
      this.chapterTotal = toc.items.length;
    } catch (error) {
      this.chapters = [];
      this.chapterTotal = 0;
    }
    try {
      const stats: ReadingStats = await appStore.api.readingStats();
      this.stats = stats;
      this.bookStat = this.findStat(stats, id);
    } catch (error) {
      this.stats = emptyStats();
      this.bookStat = null;
    }
    try {
      this.readlists = await appStore.api.readlistsOfBook(id);
    } catch (error) {
      this.readlists = [];
    }
    try {
      this.wanted = await appStore.api.wantToReadState(id);
    } catch (error) {
      this.wanted = false;
    }
  }

  private async toggleWant(): Promise<void> {
    const next: boolean = !this.wanted;
    try {
      await appStore.api.setWantToRead(this.book.id, next);
      this.wanted = next;
      promptAction.showToast({ message: next ? t('已加入待读') : t('已移出待读') });
    } catch (error) {
      promptAction.showToast({ message: t(`操作失败：${(error as Error).message}`) });
    }
  }

  private async mark(completed: boolean): Promise<void> {
    try {
      await appStore.api.markRead(this.book.id, completed);
      const detail: BookItem = await appStore.api.book(this.book.id);
      ProgressMarks.settle(detail.id, completed, detail.pages);
      this.book = detail;
      appStore.selected = detail;
      promptAction.showToast({ message: completed ? t('已标记为读完') : t('已标记为未读') });
    } catch (error) {
      hilog.warn(0x0000, 'LantaiReader', 'mark read %{public}s failed: %{public}s',
        `${completed}`, (error as Error).message);
      promptAction.showToast({ message: t(`操作失败：${(error as Error).message}`) });
    }
  }

  private findStat(stats: ReadingStats, id: string): BookStat | null {
    for (let index = 0; index < stats.books.length; index++) {
      if (stats.books[index].bookId === id) {
        return stats.books[index];
      }
    }
    return null;
  }

  private async cachedOf(id: string): Promise<boolean> {
    if (offlineCache.has(`/api/lantai/v1/read/${id}/bootstrap?images=inline&w=0&window=3`)) {
      return true;
    }
    try {
      const rows: OfflineBookRow[] = await offlineDb.books();
      for (let index = 0; index < rows.length; index++) {
        if (rows[index].bookId === id) {
          return true;
        }
      }
    } catch (error) {
    }
    return false;
  }

  private async cacheBook(): Promise<void> {
    if (this.book.profile === 'PDF') {
      promptAction.showToast({ message: t('PDF 暂不支持离线缓存') });
      return;
    }
    if (this.cached) {
      this.nav.pushPathByName('downloads', null);
      return;
    }
    await downloader.enqueue(this.book, this.book.profile);
    this.cached = true;
    promptAction.showToast({ message: t('已加入下载队列') });
  }

  private openReader(): void {
    appStore.readerIncognito = false;
    this.enterReader();
  }

  private openReaderHidden(): void {
    appStore.readerIncognito = true;
    this.enterReader();
  }

  private unreadable(): boolean {
    return this.book.mediaStatus === MEDIA_ERROR;
  }

  private page(): number {
    return ProgressMarks.pageOf(this.book.id, this.book.readPage);
  }

  private done(): boolean {
    return ProgressMarks.doneOf(this.book.id, this.book.readCompleted, this.page(), this.book.pages);
  }

  private enterReader(): void {
    if (this.unreadable()) {
      promptAction.showToast({ message: t('文件损坏，无法阅读') });
      return;
    }
    appStore.readerBookId = this.book.id;
    appStore.readerTitle = this.book.title;
    appStore.readerChapter = Math.max(1, this.page());
    if (!isEbook(this.book.profile)) {
      this.nav.pushPathByName('comic', null);
      return;
    }
    this.nav.pushPathByName('reader', null);
  }

  private openChapter(target: number): void {
    appStore.readerIncognito = false;
    appStore.readerBookId = this.book.id;
    appStore.readerTitle = this.book.title;
    appStore.readerChapter = target;
    if (!isEbook(this.book.profile)) {
      this.nav.pushPathByName('comic', null);
      return;
    }
    this.nav.pushPathByName('reader', null);
  }

  private percent(): number {
    return this.done() ? 100 : F.percent(this.page(), this.book.pages);
  }

  private readStateLabel(): string {
    return F.progressLabel(this.page(), this.book.pages, this.done());
  }

  private listLabel(): string {
    if (this.readlists.length === 0) {
      return '';
    }
    if (this.readlists.length === 1) {
      return this.readlists[0].name;
    }
    return `${this.readlists[0].name} +${this.readlists.length - 1}`;
  }

  private pagesLabel(): string {
    const pages: string = this.book.pages > 0 ? t(`${this.book.pages} 页`) : '—';
    if (isEbook(this.book.profile) && this.chapterTotal > 0) {
      return t(`${pages} / ${this.chapterTotal} 章`);
    }
    return pages;
  }

  private progressLine(): string {
    const pages: string = this.book.pages > 0 ? t(`${this.book.pages} 页`) : '';
    if (isEbook(this.book.profile) && this.chapterTotal > 0) {
      return tf('{0} · {1} · {2} 章', [this.readStateLabel(), pages, `${this.chapterTotal}`]);
    }
    if (this.book.readDate.length > 0) {
      return tf('{0} · {1} · 上次 {2}', [this.readStateLabel(), pages, F.ago(this.book.readDate)]);
    }
    return `${this.readStateLabel()} · ${pages}`;
  }

  private durationValue(): string {
    const stat: BookStat | null = this.bookStat;
    return stat === null ? '—' : F.shortDuration(stat.durationMs);
  }

  private recentValue(): string {
    const stat: BookStat | null = this.bookStat;
    if (stat === null || stat.lastReadAt.length === 0) {
      return '—';
    }
    return F.ago(stat.lastReadAt);
  }

  private pagesReadValue(): string {
    const stat: BookStat | null = this.bookStat;
    return stat === null ? '—' : `${stat.pagesRead}`;
  }

  private sessionValue(): string {
    const stat: BookStat | null = this.bookStat;
    return stat === null ? '—' : `${stat.sessionCount}`;
  }

  private pageSize(): number {
    return this.tocMode === 'grid' ? this.gridSize : this.listSize;
  }

  private pageCount(): number {
    return Math.max(1, Math.ceil(this.chapters.length / this.pageSize()));
  }

  private shownChapters(): ChapterItem[] {
    const page: number = Math.min(this.tocPage, this.pageCount() - 1);
    const size: number = this.pageSize();
    return this.chapters.slice(page * size, page * size + size);
  }

  private pageList(): number[] {
    const total: number = this.pageCount();
    const cur: number = Math.min(this.tocPage, total - 1);
    const out: number[] = [];
    if (total <= 7) {
      for (let index = 0; index < total; index++) {
        out.push(index);
      }
      return out;
    }
    let from: number = Math.max(1, cur - 1);
    let to: number = Math.min(total - 2, cur + 1);
    if (cur <= 3) {
      from = 1;
      to = 4;
    }
    if (cur >= total - 4) {
      from = total - 5;
      to = total - 2;
    }
    out.push(0);
    if (from > 1) {
      out.push(-1);
    }
    for (let index = from; index <= to; index++) {
      out.push(index);
    }
    if (to < total - 2) {
      out.push(-1);
    }
    out.push(total - 1);
    return out;
  }

  private gotoPage(page: number): void {
    this.tocPage = Math.max(0, Math.min(this.pageCount() - 1, page));
  }

  private applySize(value: number): void {
    if (this.tocMode === 'grid') {
      this.gridSize = value;
    } else {
      this.listSize = value;
    }
    this.tocPage = 0;
  }

  private openSizeDialog(): void {
    this.sizeText = `${this.pageSize()}`;
    const dialog: CustomDialogController = new CustomDialogController({
      builder: TocSizeDialog({
        value: this.sizeText,
        onOk: (value: number) => {
          this.applySize(value);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.sizeDialog = dialog;
    dialog.open();
  }

  private switchMode(mode: string): void {
    if (this.tocMode === mode) {
      return;
    }
    this.tocPinned = true;
    this.tocMode = mode;
    this.tocPage = 0;
  }

  private peak(): number {
    let peak: number = 1;
    for (let index = 0; index < this.stats.days.length; index++) {
      if (this.stats.days[index].durationMs > peak) {
        peak = this.stats.days[index].durationMs;
      }
    }
    return peak;
  }

  @Builder
  topBar() {
    ScreenHead({
      title: t('书籍详情'),
      back: t('返回'),
      onBack: () => {
        this.nav.pop();
      }
    })
  }

  @Builder
  crumb() {
    Row({ space: 4 }) {
      Text(t('书库'))
        .fontSize(10.5)
        .fontColor(C.tx3)
        .onClick(() => {
          this.nav.pop();
        })
      GlyphIcon({ glyphName: 'next', glyphSize: 11, glyphColor: C.tx4 })
      Text(this.book.seriesTitle.length > 0 ? this.book.seriesTitle : t('未归入系列'))
        .fontSize(10.5)
        .fontColor(C.tx3)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 110 })
      GlyphIcon({ glyphName: 'next', glyphSize: 11, glyphColor: C.tx4 })
      Text(this.book.title)
        .fontSize(10.5)
        .fontColor(C.tx2)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  head() {
    Row({ space: 14 }) {
      CoverImage({
        bookId: this.book.id,
        title: this.book.title,
        coverWidth: 112,
        coverHeight: 156,
        radius: 8
      })
        .onClick(() => {
          this.openCover();
        })

      Column() {
        Row({ space: 5 }) {
          FormatBadge({ label: appStore.offline ? t('离线副本') : t('云端') })
          FormatBadge({ label: profileLabel(this.book.profile, this.book.mediaStatus) })
          FormatBadge({ label: this.readStateLabel(), tone: this.book.readCompleted ? 'done' : 'normal' })
        }
        .width('100%')

        Text(this.book.title)
          .fontSize(18)
          .fontFamily(FT.disp)
          .letterSpacing(0.6)
          .fontColor(C.tx)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 8 })

        if (this.book.authors.length > 0) {
          Text(this.book.authors)
            .fontSize(11)
            .fontColor(C.tx3)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 3 })
        }

        Blank()

        Row({ space: 9 }) {
          InfoCell({ label: t('格式'), value: profileLabel(this.book.profile, this.book.mediaStatus) })
        }
        .width('100%')

        Row({ space: 9 }) {
          InfoCell({ label: isEbook(this.book.profile) ? t('页数 / 章节') : t('页数'), value: this.pagesLabel() })
          InfoCell({ label: t('出版'), value: F.day(this.book.releaseDate) })
        }
        .width('100%')
        .margin({ top: 5 })

        Row({ space: 6 }) {
          ChipOp({
            glyph: 'info',
            label: this.showInfo ? t('收起信息') : t('完整信息'),
            active: this.showInfo,
            chevron: this.showInfo ? 'up' : 'down',
            onTap: () => {
              this.showInfo = !this.showInfo;
            }
          })
          if (!appStore.offline) {
            ChipOp({
              glyph: 'readlist',
              label: this.listLabel(),
              onTap: () => {
                this.nav.pushPathByName('readlists', null);
              }
            })
          }
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .height(156)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  summaryBox() {
    if (this.book.summary.length > 0) {
      Column() {
        Text(this.book.summary)
          .fontSize(11.5)
          .fontColor(C.tx2)
          .lineHeight(20)
          .maxLines(this.showSummary ? 60 : 2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.showSummary ? t('收起') : t('展开'))
          .fontSize(10)
          .fontColor(C.acc)
          .margin({ top: 6 })
      }
      .width('100%')
      .padding(12)
      .backgroundColor(C.bg1)
      .borderRadius(R.m)
      .border({ width: 1, color: C.line })
      .margin({ top: 13 })
      .onClick(() => {
        this.showSummary = !this.showSummary;
      })
    }
  }

  @Builder
  dock() {
    Column() {
      Row({ space: 7 }) {
        Row({ space: 6 }) {
          GlyphIcon({ glyphName: 'book', glyphSize: 15, glyphColor: this.unreadable() ? C.tx4 : C.bg })
          Text(this.unreadable() ? t('无法阅读') :
            (this.page() > 0 ? t('继续阅读') : t('开始阅读')))
            .fontSize(12.5)
            .fontColor(this.unreadable() ? C.tx4 : C.bg)
            .fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1.6)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.unreadable() ? C.bg3 : C.acc)
        .borderRadius(10)
        .onClick(() => {
          this.openReader();
        })

        Row({ space: 6 }) {
          GlyphIcon({ glyphName: 'eyeOff', glyphSize: 15, glyphColor: C.tx2 })
          Text(t('隐身阅读'))
            .fontSize(12.5)
            .fontColor(C.tx2)
        }
        .layoutWeight(1)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(C.bg3)
        .borderRadius(10)
        .border({ width: 1, color: C.line })
        .onClick(() => {
          this.openReaderHidden();
        })
      }
      .width('100%')

      if (!appStore.offline) {
      Row({ space: 6 }) {
        ActCell({
          glyph: 'check',
          label: t('标记已读'),
          dimmed: this.book.readCompleted,
          onTap: () => {
            this.mark(true);
          }
        })
        ActCell({
          glyph: 'close',
          label: t('标记未读'),
          dimmed: !this.done() && this.page() <= 0,
          onTap: () => {
            this.mark(false);
          }
        })
        ActCell({
          glyph: this.wanted ? 'close' : 'bookmark',
          label: this.wanted ? t('移除待读') : t('加入待读'),
          active: this.wanted,
          onTap: () => {
            this.toggleWant();
          }
        })
        ActCell({
          glyph: 'download',
          label: this.cached ? t('已离线') : t('缓存本机'),
          active: this.cached,
          onTap: () => {
            this.cacheBook();
          }
        })
      }
      .width('100%')
      .margin({ top: 7 })
      }
    }
    .width('100%')
    .padding(9)
    .backgroundColor(C.bg2)
    .borderRadius(R.l)
    .border({ width: 1, color: C.line })
    .margin({ top: 12 })
  }

  @Builder
  statCard() {
    Column() {
      Row({ space: 6 }) {
        Text(t('阅读进度与时长'))
          .fontSize(12)
          .fontColor(C.tx)
        Blank()
        FormatBadge({ label: profileLabel(this.book.profile, this.book.mediaStatus) })
        FormatBadge({ label: `${this.percent()}%` })
      }
      .width('100%')

      ProgressBar({ percent: this.percent() })
        .margin({ top: 8 })

      Row({ space: 10 }) {
        Text(this.progressLine())
          .fontSize(10)
          .fontColor(C.tx4)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (this.bookStat !== null && this.stats.days.length > 0) {
          Row({ space: 2 }) {
            ForEach(this.stats.days, (item: DayStat, index: number) => {
              Column()
                .layoutWeight(1)
                .height(Math.max(3, Math.round(item.durationMs / this.peak() * 20)))
                .backgroundColor(index === this.stats.days.length - 1 ? C.acc2 : C.acc)
                .borderRadius(1)
            }, (item: DayStat, index: number) => `${index}-${item.date}`)
          }
          .width(76)
          .height(20)
          .alignItems(VerticalAlign.Bottom)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 8 })

      Row() {
        StatCell({ value: this.durationValue(), label: t('累计') })
        StatCell({ value: this.recentValue(), label: t('上次') })
        StatCell({ value: this.pagesReadValue(), label: t('累计页') })
        StatCell({ value: this.sessionValue(), label: t('会话') })
      }
      .width('100%')
      .margin({ top: 9 })
    }
    .width('100%')
    .padding(13)
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .margin({ top: 10 })
  }

  @Builder
  tocSection() {
    Row({ space: 8 }) {
      Text(isEbook(this.book.profile) ? t('章节列表') : t('页'))
        .fontSize(16)
        .fontFamily(FT.disp)
        .letterSpacing(1)
        .fontColor(C.tx)
      Text(`${this.chapterTotal}`)
        .fontSize(10)
        .fontFamily(FT.mono)
        .fontColor(C.tx4)
      Blank()
      if (isEbook(this.book.profile)) {
        Row({ space: 4 }) {
          Row() {
            GlyphIcon({
              glyphName: 'list',
              glyphSize: 12,
              glyphColor: this.tocMode === 'list' ? C.acc2 : C.tx4
            })
          }
          .width(26)
          .height(26)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.tocMode === 'list' ? C.accBg : C.bg3)
          .borderRadius(7)
          .border({ width: 1, color: this.tocMode === 'list' ? C.accLine : C.line })
          .onClick(() => {
            this.switchMode('list');
          })

          Row() {
            GlyphIcon({
              glyphName: 'grid',
              glyphSize: 12,
              glyphColor: this.tocMode === 'grid' ? C.acc2 : C.tx4
            })
          }
          .width(26)
          .height(26)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.tocMode === 'grid' ? C.accBg : C.bg3)
          .borderRadius(7)
          .border({ width: 1, color: this.tocMode === 'grid' ? C.accLine : C.line })
          .onClick(() => {
            this.switchMode('grid');
          })
        }
      } else {
        Text(tf('{0} 页 · 阅读器中翻阅', [`${this.book.pages}`]))
          .fontSize(10)
          .fontColor(C.tx4)
      }
    }
    .width('100%')
    .margin({ top: 22, bottom: 11 })

    Column() {
      if (this.chapters.length === 0) {
        Text(this.loading ? t('目录读取中…') : t('该书籍未提供目录'))
          .fontSize(11)
          .fontColor(C.tx4)
          .padding({ top: 14, bottom: 14 })
      } else {
        if (this.tocMode === 'grid') {
          Grid() {
            ForEach(this.shownChapters(), (item: ChapterItem, index: number) => {
              GridItem() {
                TocCell({
                  label: `${this.tocStart() + index + 1}`,
                  current: item.n === this.page(),
                  onTap: () => {
                    this.openChapter(item.n);
                  }
                })
              }
            }, (item: ChapterItem) => `${item.n}-${item.title}`)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
          .columnsGap(6)
          .rowsGap(6)
          .width('100%')
          .height(this.gridHeight())
          .margin({ top: 4, bottom: 4 })
        } else {
          ForEach(this.shownChapters(), (item: ChapterItem) => {
            TocRow({
              title: item.title,
              meta: isEbook(this.book.profile) ? charsLabel(item.chars) : '',
              current: item.n === this.page(),
              onTap: () => {
                this.openChapter(item.n);
              }
            })
          }, (item: ChapterItem) => `${item.n}-${item.title}`)
        }

        this.tocPager()
      }
    }
    .width('100%')
    .padding({ left: 13, right: 13 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
  }

  @Builder
  tocPager() {
    Row({ space: 6 }) {
      Row() {
        GlyphIcon({
          glyphName: 'back',
          glyphSize: 12,
          glyphColor: this.tocPage <= 0 ? C.tx4 : C.tx2
        })
      }
      .width(28)
      .height(26)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(C.bg3)
      .borderRadius(7)
      .border({ width: 1, color: C.line })
      .opacity(this.tocPage <= 0 ? 0.4 : 1)
      .onClick(() => {
        this.gotoPage(this.tocPage - 1);
      })

      Scroll() {
        Row({ space: 2 }) {
          ForEach(this.pageList(), (item: number, index: number) => {
            TocNum({
              label: item < 0 ? '…' : `${item + 1}`,
              active: item === Math.min(this.tocPage, this.pageCount() - 1),
              gap: item < 0,
              onTap: () => {
                this.gotoPage(item);
              }
            })
          }, (item: number, index: number) => `${index}-${item}`)
        }
        .alignItems(VerticalAlign.Center)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .height(24)

      Row() {
        GlyphIcon({
          glyphName: 'next',
          glyphSize: 12,
          glyphColor: this.tocPage >= this.pageCount() - 1 ? C.tx4 : C.tx2
        })
      }
      .width(28)
      .height(26)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(C.bg3)
      .borderRadius(7)
      .border({ width: 1, color: C.line })
      .opacity(this.tocPage >= this.pageCount() - 1 ? 0.4 : 1)
      .onClick(() => {
        this.gotoPage(this.tocPage + 1);
      })

      Row({ space: 3 }) {
        Text(t(`每页 ${this.pageSize()}`))
          .fontSize(9.5)
          .fontFamily(FT.mono)
          .fontColor(C.tx3)
        GlyphIcon({ glyphName: 'down', glyphSize: 9, glyphColor: C.tx4 })
      }
      .height(26)
      .padding({ left: 8, right: 6 })
      .backgroundColor(C.bg3)
      .borderRadius(7)
      .border({ width: 1, color: C.line })
      .bindMenu(this.sizeMenuItems())
    }
    .width('100%')
    .margin({ top: 8, bottom: 10 })
  }

  private tocStart(): number {
    return Math.min(this.tocPage, this.pageCount() - 1) * this.pageSize();
  }

  private gridHeight(): number {
    const rows: number = Math.max(1, Math.ceil(this.shownChapters().length / 5));
    return rows * 34 + (rows - 1) * 6;
  }

  private sizeMenuItems(): MenuElement[] {
    return [
      { value: t('每页 10'), action: () => { this.applySize(10); } },
      { value: t('每页 20'), action: () => { this.applySize(20); } },
      { value: t('每页 50'), action: () => { this.applySize(50); } },
      { value: t('每页 100'), action: () => { this.applySize(100); } },
      { value: t('自定义…'), action: () => { this.openSizeDialog(); } }
    ];
  }

  @Builder
  fullInfo() {
    Column({ space: 7 }) {
      Text(t('文件信息'))
        .fontSize(12)
        .fontColor(C.tx)
        .width('100%')
      Row({ space: 10 }) {
        LedgerCell({ label: t('格式'), value: profileLabel(this.book.profile, this.book.mediaStatus) })
        LedgerCell({ label: t('页数'), value: this.book.pages > 0 ? `${this.book.pages}` : '' })
      }
      .width('100%')
      Row({ space: 10 }) {
        LedgerCell({ label: t('媒体类型'), value: this.book.mediaType, mono: true })
        LedgerCell({ label: t('出版'), value: F.day(this.book.releaseDate) })
      }
      .width('100%')
      LedgerLine({ label: t('文件名'), value: this.book.fileName, mono: true })
      LedgerLine({ label: t('相对路径'), value: this.book.filePath, mono: true })
      LedgerLine({ label: t('文件哈希'), value: this.book.fileHash, mono: true })
      Row({ space: 10 }) {
        LedgerCell({ label: t('入库时间'), value: F.stamp(this.book.created) })
        LedgerCell({ label: t('文件修改'), value: F.stamp(this.book.fileModified) })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .margin({ top: 12 })

    Column({ space: 7 }) {
      Text(t('元数据'))
        .fontSize(12)
        .fontColor(C.tx)
        .width('100%')
      LedgerLine({ label: t('书名'), value: this.book.title })
      Row({ space: 10 }) {
        LedgerCell({ label: t('作者'), value: this.book.authors })
        LedgerCell({ label: t('出版社'), value: this.book.publisher })
      }
      .width('100%')
      Row({ space: 10 }) {
        LedgerCell({ label: t('序号'), value: this.book.number })
        LedgerCell({ label: t('排序序号'), value: this.book.numberSort > 0 ? `${this.book.numberSort}` : '' })
      }
      .width('100%')
      Row({ space: 10 }) {
        LedgerCell({ label: t('出版日期'), value: F.day(this.book.releaseDate) })
        LedgerCell({ label: t('语言'), value: this.book.language })
      }
      .width('100%')
      Row({ space: 10 }) {
        LedgerCell({ label: 'ISBN', value: this.book.isbn, mono: true })
        LedgerCell({ label: t('分类'), value: this.book.genres.join(' / ') })
      }
      .width('100%')
      LedgerLine({ label: t('标签'), value: this.book.tags.join(' · ') })
      Row({ space: 10 }) {
        LedgerCell({ label: t('显著实体'), value: this.book.notableCount > 0 ? t(`${this.book.notableCount} 个`) : '' })
        LedgerCell({ label: t('锁定字段'), value: this.book.lockedCount > 0 ? t(`${this.book.lockedCount} 个`) : t('无') })
      }
      .width('100%')
      if (this.book.linkCount > 0) {
        LedgerLine({ label: t('外链'), value: t(`${this.book.linkCount} 个`) })
      }
      LedgerLine({ label: t('元数据更新'), value: F.stamp(this.book.metaUpdated) })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .margin({ top: 10 })
  }

  build() {
    Stack() {
      Column() {
        this.topBar()

        if (this.loading) {
          Column() {
            LoadingProgress().width(32).height(32).color(C.acc)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              this.crumb()
              this.head()
              this.summaryBox()
              if (this.showInfo) {
                this.fullInfo()
              }
              this.dock()
              if (!appStore.offline) {
                this.statCard()
                this.tocSection()
              }
              if (this.error.length > 0) {
                Text(this.error)
                  .fontSize(11)
                  .fontColor(C.bad)
                  .width('100%')
                  .margin({ top: 12 })
              }
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
      }
      .width('100%')
      .height('100%')
      .backgroundColor(C.bg)

      if (this.coverOpen && this.book.id.length > 0) {
        CoverViewer({
          bookId: this.book.id,
          title: this.book.title,
          onClose: () => {
            this.closeCover();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
