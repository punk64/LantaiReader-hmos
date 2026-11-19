import { C, FT, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { ProgressMarks } from '../common/ProgressMarks';
import { appStore } from '../model/AppStore';
import { BookItem, BookPage, BookQuery, SeriesCard as SeriesStat, SeriesPage, emptyBook, emptyQuery } from '../model/LantaiModels';
import { BookGridCell, BookRow, Chip, CoverProgress } from '../components/BookViews';
import { CoverImage } from '../components/CoverImage';
import { ErrorView, LoadingView, SectionHead } from '../components/StateViews';
import { LibrarySkeleton } from '../components/Skeletons';
import { SeriesCache } from '../net/SeriesCache';
import { ScreenHead } from '../components/Shell';
import { GlyphIcon } from '../components/Icon';
import { LocalBook, LocalLibrary } from '../net/LocalLibrary';
import { LocalMeta, LocalMetas, localMetas } from '../net/LocalMeta';
import { LocalStore } from '../net/LocalStore';
import { LocalFiles } from '../net/LocalFiles';
import { localBookSource } from '../net/LocalBookSource';
import { ArchiveBook, ComicArchive, comicArchive } from '../net/ComicArchive';
import { OfflineBookRow, offlineDb } from '../data/OfflineDb';
import { promptAction } from '@kit.ArkUI';
import { fileUri } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

import { t, tf } from '../common/I18n';
interface FilterOption {
  label: string;
  value: string;
}

function formats(): FilterOption[] {
  return [
    { label: t('全部'), value: '' },
    { label: 'EPUB', value: 'EPUB' },
    { label: t('漫画'), value: 'DIVINA' },
    { label: 'PDF', value: 'PDF' }
  ];
}

function states(): FilterOption[] {
  return [
    { label: t('全部'), value: '' },
    { label: t('未读'), value: 'UNREAD' },
    { label: t('在读'), value: 'IN_PROGRESS' },
    { label: t('已读'), value: 'READ' }
  ];
}

function sorts(): FilterOption[] {
  return [
    { label: t('按更新'), value: 'lastModified,desc' },
    { label: t('按标题'), value: 'metadata.title,asc' },
    { label: t('按添加'), value: 'created,desc' }
  ];
}

function sources(): FilterOption[] {
  return [
    { label: t('全部'), value: 'all' },
    { label: t('本地'), value: 'local' },
    { label: t('云库'), value: 'cloud' }
  ];
}

function modes(): FilterOption[] {
  return [
    { label: t('按系列'), value: 'series' },
    { label: t('全部书籍'), value: 'books' }
  ];
}

function letters(): FilterOption[] {
  return [
    { label: t('全部'), value: '' },
    { label: 'A', value: 'A' }, { label: 'B', value: 'B' }, { label: 'C', value: 'C' },
    { label: 'D', value: 'D' }, { label: 'E', value: 'E' }, { label: 'F', value: 'F' },
    { label: 'G', value: 'G' }, { label: 'H', value: 'H' }, { label: 'I', value: 'I' },
    { label: 'J', value: 'J' }, { label: 'K', value: 'K' }, { label: 'L', value: 'L' },
    { label: 'M', value: 'M' }, { label: 'N', value: 'N' }, { label: 'O', value: 'O' },
    { label: 'P', value: 'P' }, { label: 'Q', value: 'Q' }, { label: 'R', value: 'R' },
    { label: 'S', value: 'S' }, { label: 'T', value: 'T' }, { label: 'U', value: 'U' },
    { label: 'V', value: 'V' }, { label: 'W', value: 'W' }, { label: 'X', value: 'X' },
    { label: 'Y', value: 'Y' }, { label: 'Z', value: 'Z' }
  ];
}

function serials(): FilterOption[] {
  return [
    { label: t('全部'), value: '' },
    { label: t('连载中'), value: 'ONGOING' },
    { label: t('已完结'), value: 'ENDED' },
    { label: t('休刊'), value: 'HIATUS' },
    { label: t('弃坑'), value: 'ABANDONED' }
  ];
}


interface SeriesGroup {
  id: string;
  title: string;
  books: BookItem[];
}

@Component
struct SeriesCard {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop title: string = '';
  @Prop count: number = 0;
  @Prop read: number = 0;
  @Prop reading: number = 0;
  @Prop author: string = '';
  @Prop coverId: string = '';
  @Prop cellWidth: number = 104;
  @Prop seriesCover: boolean = false;
  onTap: () => void = () => {};

  private percent(): number {
    if (this.count <= 0) {
      return 0;
    }
    const touched: number = Math.min(this.count, this.read + this.reading);
    return Math.max(0, Math.round(touched * 100 / this.count));
  }

  private progressText(): string {
    if (this.count <= 0) {
      return '';
    }
    if (this.read >= this.count) {
      return t(`已读完 · ${this.count} 册`);
    }
    if (this.read <= 0 && this.reading <= 0) {
      return t(`未开始 · 共 ${this.count} 册`);
    }
    if (this.reading > 0) {
      return t(`已读 ${this.read}/${this.count} · 在读 ${this.reading}`);
    }
    return t(`已读 ${this.read}/${this.count} 册`);
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        CoverImage({
          bookId: this.coverId,
          title: this.title,
          series: this.seriesCover,
          coverWidth: this.cellWidth,
          coverHeight: this.cellWidth * 1.42,
          radius: 6
        })
        Text(t(`${this.count} 册`))
          .fontSize(9)
          .fontFamily(FT.mono)
          .fontColor('#ffffff')
          .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          .backgroundColor('#b3000000')
          .borderRadius(4)
          .margin({ right: 5, top: 5 })
        CoverProgress({
          percent: this.percent(),
          barHeight: 3
        })
          .position({ x: 0, y: this.cellWidth * 1.42 - 3 })
      }
      .width(this.cellWidth)
      .height(this.cellWidth * 1.42)
      .borderRadius(6)
      .clip(true)

      Text(this.title)
        .fontSize(11.5)
        .lineHeight(15)
        .fontColor(C.tx)
        .maxLines(2)
        .height(30)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })

      Text(this.author.length > 0 ? this.author : '—')
        .fontSize(10)
        .lineHeight(14)
        .fontColor(C.tx4)
        .maxLines(1)
        .height(14)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 2 })

      Text(this.progressText())
        .fontSize(10)
        .lineHeight(14)
        .fontColor(this.read >= this.count && this.count > 0 ? C.ok : C.tx4)
        .maxLines(1)
        .height(14)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 1 })
    }
    .width(this.cellWidth)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
struct PagerBtn {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop glyph: string = '';
  @Prop active: boolean = false;
  @Prop usable: boolean = true;
  onTap: () => void = () => {};

  build() {
    Row() {
      if (this.glyph.length > 0) {
        GlyphIcon({
          glyphName: this.glyph,
          glyphSize: 12,
          glyphColor: this.active ? C.onAcc : C.tx2
        })
      } else {
        Text(this.label)
          .fontSize(11)
          .fontColor(this.active ? C.onAcc : C.tx2)
          .fontWeight(this.active ? FontWeight.Medium : FontWeight.Normal)
      }
    }
    .height(26)
    .constraintSize({ minWidth: 26 })
    .padding({ left: 6, right: 6 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.active ? C.acc : Color.Transparent)
    .borderRadius(8)
    .border({ width: 1, color: this.active ? C.acc : C.line2 })
    .opacity(this.usable ? 1 : 0.38)
    .onClick(() => {
      if (this.usable) {
        this.onTap();
      }
    })
  }
}

@Component
struct MenuRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop glyph: string = '';
  @Prop active: boolean = false;
  onTap: () => void = () => {};

  build() {
    Row({ space: 9 }) {
      GlyphIcon({
        glyphName: this.glyph,
        glyphSize: 14,
        glyphColor: this.active ? C.acc2 : C.tx3
      })
      Text(this.label)
        .fontSize(12.5)
        .fontColor(this.active ? C.acc2 : C.tx)
        .maxLines(1)
      Blank()
      if (this.active) {
        GlyphIcon({ glyphName: 'check', glyphSize: 13, glyphColor: C.acc2 })
      }
    }
    .width('100%')
    .height(36)
    .padding({ left: 12, right: 11 })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
struct FilterRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop options: FilterOption[] = [];
  @Prop current: string = '';
  @Prop first: boolean = false;
  @Prop tail: string = '';
  @Prop tailOn: boolean = false;
  onPick: (value: string) => void = () => {};
  onTail: () => void = () => {};

  build() {
    Row() {
      Text(this.label)
        .width(38)
        .fontSize(10.5)
        .fontColor(C.tx4)
        .letterSpacing(0.5)
        .padding({ top: 5 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.options, (item: FilterOption) => {
          Row() {
            Chip({
              label: item.label,
              active: item.value === this.current,
              compact: true,
              onTap: () => {
                this.onPick(item.value);
              }
            })
          }
          .margin({ right: 5, bottom: 5 })
        }, (item: FilterOption) => `${this.label}-${item.value}`)
      }
      .layoutWeight(1)

      if (this.tail.length > 0) {
        Row({ space: 3 }) {
          Text(this.tail)
            .fontSize(10.5)
            .fontColor(this.tailOn ? C.acc2 : C.tx3)
          GlyphIcon({
            glyphName: this.tailOn ? 'up' : 'down',
            glyphSize: 11,
            glyphColor: this.tailOn ? C.acc2 : C.tx3
          })
        }
        .height(24)
        .padding({ left: 9, right: 9 })
        .backgroundColor(this.tailOn ? C.accBg : C.bg3)
        .borderRadius(12)
        .border({ width: 1, color: this.tailOn ? C.accLine : Color.Transparent })
        .margin({ left: 4, bottom: 5 })
        .onClick(() => {
          this.onTail();
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 6, bottom: 1 })
    .border({ width: { top: 1 }, color: this.first ? Color.Transparent : C.line })
  }
}

@Component
export struct LibraryPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('progressVer') @Watch('onProgressVer') progressVer: number = 0;
  @StorageLink('markRev') @Watch('onMarkRev') markRev: number = 0;
  @StorageLink('mainTab') @Watch('onTab') tab: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State text: string = '';
  @State profile: string = '';
  @State readState: string = '';
  @State letter: string = '';
  @State serial: string = '';
  @State year: string = '';
  @State years: FilterOption[] = [];
  @State serverYears: string[] = [];
  @State sort: string = 'metadata.title,asc';
  @State mode: string = 'series';
  @State view: string = 'grid';
  @State filterOpen: boolean = false;
  @State searching: boolean = false;
  @State moreOpen: boolean = false;
  @State refreshing: boolean = false;
  @State jumpText: string = '';
  @State source: string = 'all';
  @State localCount: number = 0;
  @State localScanning: boolean = false;
  @State localBooks: LocalBook[] = [];
  @State localMetas: LocalMeta[] = [];
  @State localList: BookItem[] = [];
  @State archiving: boolean = false;
  @Prop embedded: boolean = false;
  @Prop @Watch('onFocusTick') focusTick: number = 0;
  @State items: BookItem[] = [];
  @State groups: SeriesGroup[] = [];
  @State allGroups: SeriesGroup[] = [];
  @State cards: SeriesStat[] = [];
  @State seriesTotal: number = 0;
  @State seriesStat: SeriesStat[] = [];
  private seriesIndex: Map<string, SeriesStat> = new Map<string, SeriesStat>();
  @State total: number = 0;
  @State loading: boolean = true;
  @State error: string = '';
  @State page: number = 0;
  @State pageSize: number = 12;
  private timer: number = -1;
  private seq: number = 0;
  private seriesTick: number = 0;
  private parsing: boolean = false;

  aboutToAppear(): void {
    if (appStore.librarySource.length > 0) {
      this.source = appStore.librarySource;
      appStore.librarySource = '';
    }
    this.hydrateLocal();
    if (this.plain()) {
      this.refresh();
    } else {
      if (!appStore.offline) {
        this.loadYears();
        this.loadSeriesStat();
      }
      this.refresh();
    }
    if (this.focusTick > 0) {
      this.onFocusTick();
    }
  }

  private plain(): boolean {
    if (appStore.offline) {
      return false;
    }
    return this.mode === 'series' && this.source !== 'local'
      && this.text.length === 0 && this.profile.length === 0 && this.readState.length === 0
      && this.letter.length === 0 && this.serial.length === 0 && this.year.length === 0;
  }

  private seriesSort(): string {
    if (this.sort === 'metadata.title,asc') {
      return 'metadata.titleSort,asc';
    }
    return this.sort;
  }

  private ensureYears(): void {
    if (this.serverYears.length > 0) {
      return;
    }
    setTimeout(() => {
      this.loadYears();
    }, 600);
  }

  private hydrateLocal(): void {
    if (appStore.localBooks.length > 0) {
      this.localBooks = appStore.localBooks.slice();
      this.localCount = appStore.localBooks.length;
      this.localMetas = appStore.localMetas.slice();
      this.reparseLocal();
    }
    this.localList = this.localItems();
  }

  private onTab(): void {
    if (this.tab === 1) {
      this.hydrateLocal();
      if (appStore.offline) {
        this.refresh();
      }
    }
  }

  private onProgressVer(): void {
    if (appStore.localMetas.length > 0) {
      this.localMetas = appStore.localMetas.slice();
      this.localList = this.localItems();
      if (appStore.offline) {
        this.refresh();
      }
    }
  }

  private onMarkRev(): void {
    this.seriesTick = 0;
    this.loadSeriesStat(true);
  }

  private resolved(meta: LocalMeta): boolean {
    return meta.author.length > 0 || meta.pages > 0 || meta.cover.length > 0 || meta.series.length > 0;
  }

  private findMeta(id: string): LocalMeta | null {
    for (let index: number = 0; index < this.localMetas.length; index++) {
      if (this.localMetas[index].id === id) {
        return this.localMetas[index];
      }
    }
    return null;
  }

  private putMeta(meta: LocalMeta): void {
    for (let index: number = 0; index < this.localMetas.length; index++) {
      if (this.localMetas[index].id === meta.id) {
        this.localMetas = this.localMetas.map((item: LocalMeta, at: number) => at === index ? meta : item);
        return;
      }
    }
    this.localMetas = this.localMetas.concat([meta]);
  }

  private async reparseLocal(): Promise<void> {
    if (this.parsing || this.localBooks.length === 0) {
      return;
    }
    this.parsing = true;
    for (let index: number = 0; index < this.localBooks.length; index++) {
      const book: LocalBook = this.localBooks[index];
      const current: LocalMeta | null = this.findMeta(LocalMetas.idOf(book.uri));
      if (current !== null && this.resolved(current)) {
        continue;
      }
      try {
        const meta: LocalMeta = await localMetas.enrich(book);
        const kept: LocalMeta | null = this.findMeta(meta.id);
        if (kept !== null) {
          meta.chapter = kept.chapter;
          meta.progress = kept.progress;
        }
        this.putMeta(meta);
        appStore.localMetas = this.localMetas;
        await LocalStore.save(meta, appStore.localRoot);
      } catch (error) {
      }
    }
    this.parsing = false;
    this.years = this.buildYearOptions();
    this.localList = this.localItems();
  }

  private async loadSeriesStat(force: boolean = false): Promise<void> {
    const now: number = Date.now();
    if (!force && now - this.seriesTick < 20000) {
      return;
    }
    this.seriesTick = now;
    try {
      const list: SeriesStat[] = await appStore.api.seriesStats();
      const index: Map<string, SeriesStat> = new Map<string, SeriesStat>();
      for (let cursor: number = 0; cursor < list.length; cursor++) {
        index.set(list[cursor].id, list[cursor]);
      }
      this.seriesIndex = index;
      this.seriesStat = list;
    } catch (error) {
      this.seriesIndex = new Map<string, SeriesStat>();
      this.seriesStat = [];
    }
  }

  private seriesBooksOf(id: string): number {
    const hit: SeriesStat | undefined = this.seriesIndex.get(id);
    return hit === undefined ? 0 : hit.books;
  }

  private seriesReadOf(id: string): number {
    const hit: SeriesStat | undefined = this.seriesIndex.get(id);
    return hit === undefined ? 0 : hit.read;
  }

  private seriesReadingOf(id: string): number {
    const hit: SeriesStat | undefined = this.seriesIndex.get(id);
    return hit === undefined ? 0 : hit.reading;
  }

  private groupTotal(group: SeriesGroup): number {
    const total: number = this.seriesBooksOf(group.id);
    return total > 0 ? total : group.books.length;
  }

  private groupRead(group: SeriesGroup): number {
    if (this.seriesBooksOf(group.id) > 0) {
      return this.seriesReadOf(group.id);
    }
    let read: number = 0;
    for (let cursor: number = 0; cursor < group.books.length; cursor++) {
      const book: BookItem = group.books[cursor];
      const page: number = ProgressMarks.pageOf(book.id, book.readPage);
      if (ProgressMarks.doneOf(book.id, book.readCompleted, page, book.pages)) {
        read += 1;
      }
    }
    return read;
  }

  private groupReading(group: SeriesGroup): number {
    if (this.seriesBooksOf(group.id) > 0) {
      return this.seriesReadingOf(group.id);
    }
    let reading: number = 0;
    for (let cursor: number = 0; cursor < group.books.length; cursor++) {
      const book: BookItem = group.books[cursor];
      const page: number = ProgressMarks.pageOf(book.id, book.readPage);
      if (!ProgressMarks.doneOf(book.id, book.readCompleted, page, book.pages) && page > 0) {
        reading += 1;
      }
    }
    return reading;
  }

  private onFocusTick(): void {
    this.source = 'all';
    this.searching = true;
    this.moreOpen = false;
    setTimeout(() => {
      try {
        focusControl.requestFocus('librarySearch');
      } catch (error) {
      }
    }, 260);
  }

  private async loadYears(): Promise<void> {
    try {
      this.serverYears = await appStore.api.facetYears();
    } catch (error) {
      this.serverYears = [];
    }
    this.years = this.buildYearOptions();
  }

  private buildYearOptions(): FilterOption[] {
    const values: string[] = [];
    for (let index: number = 0; index < this.serverYears.length; index++) {
      values.push(this.serverYears[index]);
    }
    for (let index: number = 0; index < this.localMetas.length; index++) {
      const date: string = this.localMetas[index].date;
      if (date.length >= 4) {
        values.push(date.substring(0, 4));
      }
    }
    values.sort((a: string, b: string) => a < b ? 1 : (a > b ? -1 : 0));
    const out: FilterOption[] = [{ label: t('全部'), value: '' }];
    const seen: Set<string> = new Set<string>();
    for (let index: number = 0; index < values.length; index++) {
      const value: string = values[index];
      if (value.length !== 4 || seen.has(value)) {
        continue;
      }
      seen.add(value);
      out.push({ label: value, value: value });
    }
    return out;
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }

  private buildQuery(page: number): BookQuery {
    const query: BookQuery = emptyQuery();
    query.text = this.text.trim();
    query.profile = this.profile;
    query.readState = this.readState;
    query.letter = this.letter;
    query.serial = this.serial;
    query.year = this.year;
    query.sort = this.sort;
    query.page = page;
    query.size = this.pageSize;
    return query;
  }

  private async refresh(): Promise<void> {
    this.seq += 1;
    const current: number = this.seq;
    this.error = '';
    if (appStore.offline) {
      await this.refreshOffline();
      return;
    }
    if (this.plain()) {
      this.ensureYears();
      await this.loadCards(current);
      return;
    }
    this.loadSeriesStat();
    this.loading = true;
    try {
      if (this.mode === 'series' && this.source !== 'local') {
        const all: BookItem[] = await this.loadAll(current);
        if (current !== this.seq) {
          return;
        }
        this.allGroups = this.buildGroups(all);
        this.localList = this.localItems();
        this.total = all.length;
        this.groups = this.sliceGroups();
        this.loading = false;
        return;
      }
      this.localList = this.localItems();
      if (this.source === 'local') {
        const localPages: number = Math.max(1, Math.ceil(this.localList.length / this.pageSize));
        this.page = Math.max(0, Math.min(this.page, localPages - 1));
        this.items = [];
        this.total = 0;
        this.groups = this.buildGroups(this.localList);
        this.loading = false;
        return;
      }
      const size: number = this.pageSize;
      const start: number = this.page * size;
      const inline: number = Math.max(0, Math.min(size, this.localList.length - start));
      const need: number = size - inline;
      const cloudStart: number = Math.max(0, start - this.localList.length);
      const cloudPage: number = Math.floor(cloudStart / size);
      const shift: number = cloudStart % size;
      const query: BookQuery = this.buildQuery(cloudPage);
      query.size = need > 0 ? size + shift : 1;
      const result: BookPage = await appStore.api.books(query);
      if (current !== this.seq) {
        return;
      }
      this.total = result.total;
      if (need > 0) {
        this.items = result.items.slice(shift, shift + need);
      } else {
        this.items = [];
      }
      const pages: number = Math.max(1, Math.ceil((this.localList.length + this.total) / size));
      if (this.page > pages - 1) {
        this.page = pages - 1;
        this.refresh();
        return;
      }
      this.groups = this.buildGroups(this.items);
      this.loading = false;
    } catch (error) {
      if (current !== this.seq) {
        return;
      }
      this.loading = false;
      this.error = (error as Error).message;
    } finally {
      if (current === this.seq) {
        this.refreshing = false;
      }
    }
  }

  private offlineAsBook(row: OfflineBookRow): BookItem {
    const book: BookItem = emptyBook();
    book.id = row.bookId;
    book.title = row.title;
    book.profile = row.profile;
    book.sizeBytes = row.bytes;
    book.size = F.bytes(row.bytes);
    return book;
  }

  private matchCloud(book: BookItem): boolean {
    const key: string = this.text.trim().toLowerCase();
    if (key.length > 0 && !book.title.toLowerCase().includes(key)) {
      return false;
    }
    if (this.profile.length > 0 && book.profile !== this.profile) {
      return false;
    }
    return true;
  }

  private async refreshOffline(): Promise<void> {
    this.loading = true;
    if (this.mode !== 'books') {
      this.mode = 'books';
      this.page = 0;
    }
    try {
      const rows: OfflineBookRow[] = await offlineDb.books();
      const cloud: BookItem[] = [];
      for (let index: number = 0; index < rows.length; index++) {
        const book: BookItem = this.offlineAsBook(rows[index]);
        if (this.matchCloud(book)) {
          cloud.push(book);
        }
      }
      let list: BookItem[] = this.source === 'cloud' ? [] : this.localItems();
      if (this.source !== 'local') {
        list = list.concat(cloud);
      }
      this.localList = list;
      this.items = [];
      this.total = 0;
      this.groups = this.buildGroups(list);
      const pages: number = Math.max(1, Math.ceil(list.length / this.pageSize));
      if (this.page > pages - 1) {
        this.page = pages - 1;
      }
      this.loading = false;
      this.error = '';
    } catch (error) {
      this.loading = false;
      this.error = (error as Error).message;
    } finally {
      this.refreshing = false;
    }
  }

  private async loadCards(current: number): Promise<void> {
    const key: string = SeriesCache.keyOf(this.page, this.pageSize, this.seriesSort());
    const hit: SeriesPage | undefined = SeriesCache.get(key);
    if (hit !== undefined) {
      this.cards = hit.items;
      this.seriesTotal = hit.total;
      this.loading = false;
      this.refreshing = false;
      this.prefetchNext();
      return;
    }
    if (this.cards.length === 0) {
      this.loading = true;
    }
    try {
      const page: SeriesPage = await appStore.api.seriesPage(this.page, this.pageSize, this.seriesSort());
      if (current !== this.seq) {
        return;
      }
      SeriesCache.put(key, page);
      this.cards = page.items;
      this.seriesTotal = page.total;
      this.loading = false;
      this.prefetchNext();
    } catch (error) {
      if (current !== this.seq) {
        return;
      }
      this.loading = false;
      this.error = (error as Error).message;
    } finally {
      if (current === this.seq) {
        this.refreshing = false;
      }
    }
  }

  private prefetchNext(): void {
    const next: number = this.page + 1;
    if (next >= this.pageCount()) {
      return;
    }
    const key: string = SeriesCache.keyOf(next, this.pageSize, this.seriesSort());
    if (SeriesCache.get(key) !== undefined) {
      return;
    }
    appStore.api.seriesPage(next, this.pageSize, this.seriesSort())
      .then((page: SeriesPage) => {
        SeriesCache.put(key, page);
      })
      .catch(() => {
      });
  }

  private async loadAll(current: number): Promise<BookItem[]> {
    const out: BookItem[] = [];
    const step: number = 500;
    for (let page: number = 0; page < 20; page++) {
      const query: BookQuery = this.buildQuery(page);
      query.size = step;
      const result: BookPage = await appStore.api.books(query);
      if (current !== this.seq) {
        return out;
      }
      for (let index: number = 0; index < result.items.length; index++) {
        out.push(result.items[index]);
      }
      if (result.items.length < step || out.length >= result.total) {
        break;
      }
    }
    return out;
  }

  private sliceGroups(): SeriesGroup[] {
    const start: number = this.page * this.pageSize;
    return this.allGroups.slice(start, start + this.pageSize);
  }

  private onPullRefresh(): void {
    this.page = 0;
    this.jumpText = '';
    if (!appStore.offline) {
      this.loadYears();
      if (!this.plain()) {
        this.loadSeriesStat(true);
      }
    }
    this.refresh();
  }

  private buildGroups(list: BookItem[]): SeriesGroup[] {
    const order: string[] = [];
    const buckets: Map<string, BookItem[]> = new Map<string, BookItem[]>();
    for (let index = 0; index < list.length; index++) {
      const book: BookItem = list[index];
      const key: string = book.seriesTitle.length > 0 ? book.seriesTitle : t('未归入系列');
      if (!buckets.has(key)) {
        buckets.set(key, []);
        order.push(key);
      }
      const bucket: BookItem[] | undefined = buckets.get(key);
      if (bucket !== undefined) {
        bucket.push(book);
      }
    }
    const out: SeriesGroup[] = [];
    for (let index = 0; index < order.length; index++) {
      const key: string = order[index];
      const bucket: BookItem[] | undefined = buckets.get(key);
      if (bucket === undefined) {
        continue;
      }
      const head: BookItem = bucket[0];
      out.push({ id: head.seriesId, title: key, books: bucket });
    }
    return out;
  }

  private pageCount(): number {
    if (this.plain()) {
      return Math.max(1, Math.ceil(this.seriesTotal / this.pageSize));
    }
    if (this.mode === 'series' && this.source !== 'local') {
      return Math.max(1, Math.ceil(this.allGroups.length / this.pageSize));
    }
    if (this.source === 'local') {
      return Math.max(1, Math.ceil(this.localList.length / this.pageSize));
    }
    return Math.max(1, Math.ceil((this.localList.length + this.total) / this.pageSize));
  }

  private turn(delta: number): void {
    const next: number = this.page + delta;
    if (next < 0 || next >= this.pageCount()) {
      return;
    }
    this.goto(next);
  }

  private goto(target: number): void {
    const next: number = Math.max(0, Math.min(this.pageCount() - 1, target));
    this.jumpText = '';
    if (next === this.page) {
      return;
    }
    this.page = next;
    if (this.plain()) {
      this.refresh();
      return;
    }
    if (this.mode === 'series' && this.source !== 'local') {
      this.groups = this.sliceGroups();
      return;
    }
    this.refresh();
  }

  private jumpTo(): void {
    const raw: string = this.jumpText.trim();
    if (raw.length === 0) {
      return;
    }
    const target: number = parseInt(raw, 10);
    if (!isNaN(target)) {
      this.goto(target - 1);
    }
    this.jumpText = '';
  }

  private setPageSize(size: number): void {
    this.jumpText = '';
    if (size === this.pageSize) {
      return;
    }
    this.pageSize = size;
    this.page = 0;
    if (this.plain()) {
      this.refresh();
      return;
    }
    if (this.mode === 'series' && this.source !== 'local') {
      this.groups = this.sliceGroups();
      return;
    }
    this.refresh();
  }

  private pgNums(): number[] {
    const pages: number = this.pageCount();
    const cur: number = this.page + 1;
    const out: number[] = [];
    if (pages <= 7) {
      for (let index: number = 1; index <= pages; index++) {
        out.push(index);
      }
      return out;
    }
    out.push(1);
    const from: number = Math.max(2, cur - 1);
    const to: number = Math.min(pages - 1, cur + 1);
    if (from > 2) {
      out.push(0);
    }
    for (let index: number = from; index <= to; index++) {
      out.push(index);
    }
    if (to < pages - 1) {
      out.push(0);
    }
    out.push(pages);
    return out;
  }

  private onSearchInput(value: string): void {
    this.text = value;
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
    if (appStore.offline) {
      this.timer = setTimeout(() => {
        this.timer = -1;
        this.page = 0;
        this.refresh();
      }, 220);
      return;
    }
    if (this.source === 'local') {
      this.page = 0;
      this.localList = this.localItems();
      return;
    }
    this.timer = setTimeout(() => {
      this.timer = -1;
      this.page = 0;
      this.refresh();
    }, 400);
  }

  private openDetail(book: BookItem): void {
    appStore.selected = book;
    this.nav.pushPathByName('book', null);
  }

  private openSeries(group: SeriesGroup): void {
    if (group.id.length === 0) {
      return;
    }
    appStore.selectedSeriesId = group.id;
    this.nav.pushPathByName('series', null);
  }

  private openSeriesId(id: string): void {
    if (id.length === 0) {
      return;
    }
    appStore.selectedSeriesId = id;
    this.nav.pushPathByName('series', null);
  }

  private apply(kind: string, value: string): void {
    if (appStore.offline) {
      if (kind === 'source') {
        this.source = value;
      } else if (kind === 'format') {
        this.profile = value;
      } else if (kind === 'state') {
        this.readState = value;
      } else if (kind === 'letter') {
        this.letter = value;
      } else if (kind === 'serial') {
        this.serial = value;
      } else if (kind === 'year') {
        this.year = value;
      } else if (kind === 'sort') {
        this.sort = value;
      } else {
        return;
      }
      this.page = 0;
      this.refresh();
      return;
    }
    if (kind === 'mode') {
      this.mode = value;
      this.page = 0;
      if (this.source !== 'local') {
        this.refresh();
      }
      return;
    }
    if (kind === 'source') {
      this.source = value;
      this.page = 0;
      if (value === 'local') {
        this.localList = this.localItems();
        this.loading = false;
        this.error = '';
        return;
      }
      this.refresh();
      return;
    }
    if (kind === 'format') {
      this.profile = value;
    } else if (kind === 'state') {
      this.readState = value;
    } else if (kind === 'letter') {
      this.letter = value;
    } else if (kind === 'serial') {
      this.serial = value;
    } else if (kind === 'year') {
      this.year = value;
    } else if (kind === 'sort') {
      this.sort = value;
    }
    this.page = 0;
    this.refresh();
  }

  private resetFilters(): void {
    this.text = '';
    this.profile = '';
    this.readState = '';
    this.letter = '';
    this.serial = '';
    this.year = '';
    this.sort = 'metadata.title,asc';
    this.mode = 'series';
    this.source = 'all';
    this.filterOpen = false;
    this.page = 0;
    this.jumpText = '';
    this.refresh();
  }

  private seedOf(book: LocalBook): LocalMeta {
    return LocalMetas.seed(book);
  }

  private adoptLocal(books: LocalBook[]): void {
    this.localBooks = books;
    this.localCount = books.length;
    appStore.localBooks = books;
    appStore.localMissing = [];
    const seeds: LocalMeta[] = [];
    for (let index: number = 0; index < books.length; index++) {
      const seed: LocalMeta = this.seedOf(books[index]);
      const kept: LocalMeta | null = this.findMeta(seed.id);
      if (kept !== null) {
        seed.chapter = kept.chapter;
        seed.progress = kept.progress;
      }
      seeds.push(seed);
    }
    this.localMetas = seeds;
    appStore.localMetas = seeds;
    LocalStore.persist(seeds, appStore.localRoot);
    this.parseLocal(books);
  }

  private async parseLocal(books: LocalBook[]): Promise<void> {
    for (let index: number = 0; index < books.length; index++) {
      try {
        const meta: LocalMeta = await localMetas.enrich(books[index]);
        const kept: LocalMeta | null = this.findMeta(meta.id);
        if (kept !== null) {
          meta.chapter = kept.chapter;
          meta.progress = kept.progress;
        }
        this.putMeta(meta);
        appStore.localMetas = this.localMetas;
        await LocalStore.save(meta, appStore.localRoot);
      } catch (error) {
      }
    }
    this.years = this.buildYearOptions();
  }

  private async scanLocal(): Promise<void> {
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    this.localScanning = true;
    try {
      if (LocalLibrary.supportsFolders()) {
        const uri: string = await LocalLibrary.pickFolder(context);
        if (uri.length === 0) {
          this.localScanning = false;
          return;
        }
        await LocalLibrary.authorize(uri);
        const scanned: LocalBook[] = await LocalLibrary.scan(uri);
        const books: LocalBook[] = await LocalLibrary.adopt(context, scanned);
        appStore.localRoot = uri;
        LocalStore.persistRoot(uri);
        appStore.localRootStale = false;
        this.adoptLocal(books);
        this.source = 'local';
        promptAction.showToast({ message: t(`扫描到 ${books.length} 本`) });
      } else if (LocalLibrary.supportsFiles()) {
        const uris: string[] = await LocalLibrary.pickFiles(context);
        if (uris.length === 0) {
          this.localScanning = false;
          return;
        }
        const books: LocalBook[] = [];
        const filesDir: string = context.filesDir;
        for (let index: number = 0; index < uris.length; index++) {
          const name: string = new fileUri.FileUri(uris[index]).name;
          if (!LocalLibrary.isBook(name)) {
            continue;
          }
          let uri: string = '';
          try {
            uri = await LocalFiles.importFile(filesDir, uris[index], name);
          } catch (error) {
            continue;
          }
          books.push({ name: name, uri: uri, size: await LocalFiles.statSize(uri) });
        }
        if (books.length === 0) {
          promptAction.showToast({ message: t('所选文件中没有可识别的书籍格式') });
          this.localScanning = false;
          return;
        }
        appStore.localRoot = 'picked';
        LocalStore.persistRoot('picked');
        appStore.localRootStale = false;
        this.adoptLocal(books);
        this.source = 'local';
        promptAction.showToast({ message: t(`已选 ${books.length} 本`) });
      } else {
        promptAction.showToast({ message: t('当前系统不支持本地书库') });
      }
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      promptAction.showToast({ message: t(`扫描失败 ${err.code}：${err.message}`) });
    }
    this.localScanning = false;
  }

  private async openLocal(book: LocalBook): Promise<void> {
    if (this.archiving) {
      return;
    }
    if (ComicArchive.isReadable(book.name)) {
      this.archiving = true;
      try {
        const path: string = LocalLibrary.toPath(book.uri);
        const opened: ArchiveBook = await comicArchive.open(path, book.name, book.size);
        const id: string = LocalMetas.idOf(book.uri);
        const meta: LocalMeta | null = this.metaOf(id);
        appStore.localArchive = opened;
        appStore.localArchiveId = id;
        appStore.localArchivePage = meta !== null && meta.chapter > 0 ? meta.chapter : 1;
        this.nav.pushPathByName('comic', null);
      } catch (error) {
        promptAction.showToast({ message: t(`打开失败：${(error as Error).message}`) });
      } finally {
        this.archiving = false;
      }
      return;
    }
    const meta: LocalMeta | null = this.metaOf(LocalMetas.idOf(book.uri));
    if (meta === null) {
      promptAction.showToast({ message: t('这本书还没有完成解析') });
      return;
    }
    const blocked: string = await localBookSource.preflight(meta.id);
    if (blocked.length > 0) {
      promptAction.showToast({ message: t(blocked) });
      return;
    }
    appStore.readerBookId = meta.id;
    appStore.readerTitle = meta.title.length > 0 ? meta.title : meta.name;
    appStore.readerChapter = meta.chapter > 0 ? meta.chapter : 1;
    appStore.readerIncognito = false;
    this.nav.pushPathByName('reader', null);
  }

  private localAsBook(meta: LocalMeta): BookItem {
    const book: BookItem = emptyBook();
    book.id = meta.id;
    book.title = meta.title;
    book.seriesTitle = meta.series;
    book.profile = meta.profile;
    book.pages = meta.pages;
    book.sizeBytes = meta.sizeBytes;
    book.size = meta.sizeBytes > 0 ? F.bytes(meta.sizeBytes) : '';
    book.authors = meta.author;
    book.publisher = meta.publisher;
    book.releaseDate = meta.date;
    book.fileName = meta.name;
    book.filePath = meta.uri;
    book.readPage = meta.chapter;
    if (meta.pages > 0 && meta.chapter >= meta.pages) {
      book.readCompleted = true;
      book.readState = 'READ';
    } else if (meta.chapter > 0) {
      book.readState = 'IN_PROGRESS';
    } else {
      book.readState = 'UNREAD';
    }
    return book;
  }

  private matchLocal(meta: LocalMeta): boolean {
    const key: string = this.text.trim().toLowerCase();
    if (key.length > 0) {
      const hay: string = `${meta.title} ${meta.author} ${meta.name}`.toLowerCase();
      if (!hay.includes(key)) {
        return false;
      }
    }
    if (this.profile.length > 0 && meta.profile !== this.profile) {
      return false;
    }
    if (!appStore.offline && this.year.length > 0 && meta.date.substring(0, 4) !== this.year) {
      return false;
    }
    return true;
  }

  private metaOf(id: string): LocalMeta | null {
    for (let index: number = 0; index < this.localMetas.length; index++) {
      if (this.localMetas[index].id === id) {
        return this.localMetas[index];
      }
    }
    return null;
  }

  private contentMeta(): string {
    if (this.plain()) {
      return t(`${this.seriesTotal} 个系列`);
    }
    if (this.mode === 'series' && this.source !== 'local') {
      return t(`${this.allGroups.length} 个系列`);
    }
    if (this.source === 'local') {
      return t(`${this.localList.length} 册`);
    }
    return t(`${this.localList.length + this.total} 册`);
  }

  private isEmptyList(): boolean {
    if (this.plain()) {
      return this.cards.length === 0;
    }
    if (this.mode === 'series' && this.source !== 'local') {
      return this.allGroups.length === 0;
    }
    if (this.source === 'local') {
      return this.localList.length === 0;
    }
    return this.localList.length + this.total === 0;
  }

  private emptyTitle(): string {
    if (appStore.offline && this.source === 'cloud') {
      return t('还没有下载到本机的云库书');
    }
    return t('没有符合条件的书');
  }

  private emptySub(): string {
    if (appStore.offline && this.source === 'cloud') {
      return t('在线时在书籍详情页选择缓存本机');
    }
    return t('放宽筛选，或导入本地文件');
  }

  private localItems(): BookItem[] {
    const out: BookItem[] = [];
    if (this.source === 'cloud') {
      return out;
    }
    for (let index: number = 0; index < this.localMetas.length; index++) {
      const meta: LocalMeta = this.localMetas[index];
      if (this.matchLocal(meta)) {
        out.push(this.localAsBook(meta));
      }
    }
    return out;
  }

  private displayBooks(): BookItem[] {
    const start: number = this.page * this.pageSize;
    const out: BookItem[] = this.localList.slice(start, start + this.pageSize);
    if (this.source !== 'local') {
      for (let index: number = 0; index < this.items.length; index++) {
        out.push(this.items[index]);
      }
    }
    return out;
  }

  private openAny(book: BookItem): void {
    if (!book.id.startsWith('local:')) {
      this.openDetail(book);
      return;
    }
    const meta: LocalMeta | null = this.metaOf(book.id);
    if (meta === null) {
      return;
    }
    if (appStore.localMissing.includes(meta.id)) {
      promptAction.showToast({ message: t('文件已缺失，请重新导入') });
      return;
    }
    this.openLocal({ name: meta.name, uri: meta.uri, size: meta.sizeBytes });
  }

  private activeFilters(): boolean {
    if (appStore.offline) {
      return this.text.length > 0 || this.profile.length > 0 || this.source !== 'all';
    }
    return this.text.length > 0 || this.profile.length > 0 || this.readState.length > 0
      || this.letter.length > 0 || this.serial.length > 0 || this.year.length > 0
      || this.sort !== 'metadata.title,asc' || this.mode !== 'series' || this.source !== 'all';
  }

  @Builder
  searchBox(hint: string) {
    Row({ space: 8 }) {
      GlyphIcon({ glyphName: 'search', glyphSize: 15, glyphColor: C.tx4 })
      TextInput({ text: this.text, placeholder: hint })
        .key('librarySearch')
        .layoutWeight(1)
        .height(38)
        .fontSize(12.5)
        .backgroundColor(Color.Transparent)
        .fontColor(C.tx)
        .placeholderColor(C.tx4)
        .padding(0)
        .borderRadius(0)
        .onChange((value: string) => {
          this.onSearchInput(value);
        })
      if (this.text.length > 0) {
        GlyphIcon({ glyphName: 'close', glyphSize: 14, glyphColor: C.tx4 })
          .onClick(() => {
            this.text = '';
            this.page = 0;
            if (appStore.offline || this.source !== 'local') {
              this.refresh();
            } else {
              this.localList = this.localItems();
            }
          })
      }
    }
    .width('100%')
    .height(38)
    .padding({ left: 10, right: 10 })
    .backgroundColor(C.bg2)
    .borderRadius(11)
    .border({ width: 1, color: C.line2 })
    .margin({ top: 10 })
  }

  @Builder
  filterBox() {
    Column() {
      FilterRow({
        label: t('来源'),
        options: sources(),
        current: this.source,
        first: true,
        onPick: (value: string) => {
          this.apply('source', value);
        }
      })
      if (!appStore.offline) {
        FilterRow({
          label: t('显示'),
          options: modes(),
          current: this.mode,
          first: false,
          onPick: (value: string) => {
            this.apply('mode', value);
          }
        })
      }
      if (this.filterOpen && !appStore.offline) {
        FilterRow({
          label: t('首字母'),
          options: letters(),
          current: this.letter,
          onPick: (value: string) => {
            this.apply('letter', value);
          }
        })
        FilterRow({
          label: t('连载'),
          options: serials(),
          current: this.serial,
          onPick: (value: string) => {
            this.apply('serial', value);
          }
        })
        FilterRow({
          label: t('年份'),
          options: this.years,
          current: this.year,
          onPick: (value: string) => {
            this.apply('year', value);
          }
        })
      }
      FilterRow({
        label: t('格式'),
        options: formats(),
        current: this.profile,
        onPick: (value: string) => {
          this.apply('format', value);
        }
      })
      FilterRow({
        label: t('阅读'),
        options: states(),
        current: this.readState,
        onPick: (value: string) => {
          this.apply('state', value);
        }
      })
      FilterRow({
        label: t('排序'),
        options: sorts(),
        current: this.sort,
        tail: this.filterOpen ? t('收起') : t('更多'),
        tailOn: this.filterOpen,
        onPick: (value: string) => {
          this.apply('sort', value);
        },
        onTail: () => {
          this.filterOpen = !this.filterOpen;
        }
      })
      Row() {
        Row({ space: 5 }) {
          GlyphIcon({
            glyphName: 'sync',
            glyphSize: 11,
            glyphColor: this.activeFilters() ? C.tx3 : C.tx4
          })
          Text(t('重置全部筛选'))
            .fontSize(10.5)
            .fontColor(this.activeFilters() ? C.tx3 : C.tx4)
        }
        .height(24)
        .padding({ left: 9, right: 9 })
        .backgroundColor(C.bg3)
        .borderRadius(12)
        .border({ width: 1, color: C.line })
        .opacity(this.activeFilters() ? 1 : 0.45)
        .onClick(() => {
          if (this.activeFilters()) {
            this.resetFilters();
          }
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ top: 2, bottom: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 11, bottom: 4 })
    .backgroundColor(C.bg2)
    .borderRadius(R.l)
    .border({ width: 1, color: C.line })
    .margin({ top: 10 })
  }

  @Builder
  gridList() {
    Grid() {
      ForEach(this.displayBooks(), (item: BookItem) => {
        GridItem() {
          BookGridCell({
            book: item,
            cellWidth: 104,
            seriesBooks: this.seriesBooksOf(item.seriesId),
            seriesRead: this.seriesReadOf(item.seriesId),
            onTap: () => {
              this.openAny(item);
            }
          })
        }
      }, (item: BookItem) => item.id)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(10)
    .rowsGap(16)
    .width('100%')
    .height(this.gridHeight())
    .scrollBar(BarState.Off)
  }

  @Builder
  rowList() {
    Column() {
      ForEach(this.displayBooks(), (item: BookItem) => {
        Column() {
          BookRow({
            book: item,
            showProgress: true,
            showSeries: true,
            seriesBooks: this.seriesBooksOf(item.seriesId),
            seriesRead: this.seriesReadOf(item.seriesId),
            onTap: () => {
              this.openAny(item);
            }
          })
          Divider().color(C.line).strokeWidth(1)
        }
      }, (item: BookItem) => item.id)
    }
    .width('100%')
    .padding({ left: 13, right: 13 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
  }

  @Builder
  seriesList() {
    Grid() {
      ForEach(this.groups, (group: SeriesGroup) => {
        GridItem() {
          SeriesCard({
            title: group.title,
            count: this.groupTotal(group),
            read: this.groupRead(group),
            reading: this.groupReading(group),
            author: group.books.length > 0 ? group.books[0].authors : '',
            coverId: group.books.length > 0 ? group.books[0].id : '',
            cellWidth: 104,
            onTap: () => {
              this.openSeries(group);
            }
          })
        }
      }, (group: SeriesGroup) => `${group.id}-${group.title}-${this.groupTotal(group)}-${this.groupRead(group)}-${this.groupReading(group)}`)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(10)
    .rowsGap(16)
    .width('100%')
    .height(this.seriesGridHeight())
    .scrollBar(BarState.Off)
  }

  @Builder
  cardList() {
    Grid() {
      ForEach(this.cards, (card: SeriesStat) => {
        GridItem() {
          SeriesCard({
            title: card.title,
            count: card.books,
            read: card.read,
            reading: card.reading,
            author: card.author,
            coverId: card.id,
            seriesCover: true,
            cellWidth: 104,
            onTap: () => {
              this.openSeriesId(card.id);
            }
          })
        }
      }, (card: SeriesStat) => `${card.id}-${card.books}-${card.read}-${card.reading}-${card.title}`)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(10)
    .rowsGap(16)
    .width('100%')
    .height(this.seriesGridHeight())
    .scrollBar(BarState.Off)
  }

  @Builder
  pager() {
    Row({ space: 8 }) {
      Scroll() {
        Row({ space: 4 }) {
          PagerBtn({
            glyph: 'back',
            usable: this.page > 0,
            onTap: () => {
              this.turn(-1);
            }
          })
          ForEach(this.pgNums(), (num: number) => {
            if (num === 0) {
              Text('…')
                .fontSize(11)
                .fontColor(C.tx4)
                .padding({ left: 1, right: 1 })
            } else {
              PagerBtn({
                label: `${num}`,
                active: num === this.page + 1,
                onTap: () => {
                  this.goto(num - 1);
                }
              })
            }
          }, (num: number) => `${this.page}-${num}`)
          PagerBtn({
            glyph: 'next',
            usable: this.page < this.pageCount() - 1,
            onTap: () => {
              this.turn(1);
            }
          })
        }
        .constraintSize({ minWidth: '100%' })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      Row({ space: 4 }) {
        Text(t('每页'))
          .fontSize(10)
          .fontColor(C.tx3)
        Row({ space: 3 }) {
          Text(`${this.pageSize}`)
            .fontSize(11)
            .fontFamily(FT.mono)
            .fontColor(C.tx2)
          GlyphIcon({ glyphName: 'down', glyphSize: 10, glyphColor: C.tx3 })
        }
        .height(26)
        .padding({ left: 6, right: 5 })
        .backgroundColor(C.bg2)
        .borderRadius(8)
        .border({ width: 1, color: C.line2 })
        .bindMenu([
          { value: '6', action: () => { this.setPageSize(6); } },
          { value: '12', action: () => { this.setPageSize(12); } },
          { value: '24', action: () => { this.setPageSize(24); } }
        ])
        Text(t('跳'))
          .fontSize(10)
          .fontColor(C.tx3)
        TextInput({ text: this.jumpText, placeholder: `${this.page + 1}` })
          .type(InputType.Number)
          .width(38)
          .height(26)
          .fontSize(11)
          .fontFamily(FT.mono)
          .fontColor(C.tx)
          .placeholderColor(C.tx4)
          .textAlign(TextAlign.Center)
          .padding(0)
          .backgroundColor(C.bg2)
          .borderRadius(8)
          .border({ width: 1, color: C.line2 })
          .onChange((value: string) => {
            this.jumpText = value;
          })
          .onSubmit(() => {
            this.jumpTo();
          })
        Text(`/${this.pageCount()}`)
          .fontSize(10)
          .fontFamily(FT.mono)
          .fontColor(C.tx3)
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 9 })
    .margin({ top: 12 })
    .border({ width: { top: 1 }, color: C.line })
  }

  private gridHeight(): number {
    const rows: number = Math.max(1, Math.ceil(this.displayBooks().length / 3));
    return rows * 215 + (rows - 1) * 16;
  }

  private seriesGridHeight(): number {
    const count: number = this.plain() ? this.cards.length : this.groups.length;
    const rows: number = Math.max(1, Math.ceil(count / 3));
    return rows * 215 + (rows - 1) * 16;
  }

  @Builder
  moreMenu() {
    Column() {
      MenuRow({
        label: t('网格视图'),
        glyph: 'grid',
        active: this.view === 'grid',
        onTap: () => {
          this.view = 'grid';
          this.moreOpen = false;
        }
      })
      MenuRow({
        label: t('列表视图'),
        glyph: 'list',
        active: this.view === 'list',
        onTap: () => {
          this.view = 'list';
          this.moreOpen = false;
        }
      })
      Divider().color(C.line).strokeWidth(1).margin({ top: 5, bottom: 5 })
      MenuRow({
        label: t('导入本地文件'),
        glyph: 'upload',
        onTap: () => {
          this.moreOpen = false;
          this.nav.pushPathByName('import', null);
        }
      })
      MenuRow({
        label: t('扫描本地库'),
        glyph: 'folder',
        onTap: () => {
          this.moreOpen = false;
          this.scanLocal();
        }
      })
      if (!appStore.offline) {
        MenuRow({
          label: t('连接云库'),
          glyph: 'server',
          onTap: () => {
            this.moreOpen = false;
            this.nav.pushPathByName('server', null);
          }
        })
      }
      MenuRow({
        label: t('下载队列'),
        glyph: 'download',
        onTap: () => {
          this.moreOpen = false;
          this.nav.pushPathByName('downloads', null);
        }
      })
    }
    .width(158)
    .padding({ top: 5, bottom: 5 })
    .backgroundColor(C.bg1)
    .borderRadius(13)
    .border({ width: 1, color: C.line2 })
    .shadow({ radius: 26, color: '#73000000', offsetX: 0, offsetY: 10 })
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        ScreenHead({
          title: t('书库'),
          actionIcon3: 'search',
          actionOn3: this.searching,
          onAction3: () => {
            this.searching = !this.searching;
            if (this.searching) {
              this.moreOpen = false;
              setTimeout(() => {
                try {
                  focusControl.requestFocus('librarySearch');
                } catch (error) {
                }
              }, 260);
            } else {
              this.text = '';
              this.page = 0;
              if (appStore.offline || this.source !== 'local') {
                this.refresh();
              } else {
                this.localList = this.localItems();
              }
            }
          },
          actionIcon2: 'more',
          actionOn2: this.moreOpen,
          onAction2: () => {
            this.moreOpen = !this.moreOpen;
            if (this.moreOpen) {
              this.searching = false;
            }
          }
        })

        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            Column() {
              if (this.searching) {
                this.searchBox(t('书名 / 作者 / 系列 / 格式'))
              }
              this.filterBox()

              Text(this.plain()
                ? t(`${this.seriesTotal} 个系列`)
                : t(`共 ${this.localList.length + this.total} 册 · 本地 ${this.localMetas.length} 本`))
                .fontSize(10)
                .fontColor(C.tx4)
                .width('100%')
                .margin({ top: 6 })

              SectionHead({
                title: t('书库内容'),
                meta: this.contentMeta()
              })

              if (this.loading && this.localMetas.length === 0) {
                if (this.plain()) {
                  LibrarySkeleton()
                } else {
                  Column() {
                    LoadingView({ label: t('查询书库') })
                  }
                  .width('100%')
                  .height(240)
                }
              } else if (this.error.length > 0 && this.localMetas.length === 0) {
                Column() {
                  ErrorView({ message: this.error, onRetry: () => {
                    this.refresh();
                  } })
                }
                .width('100%')
                .height(240)
              } else if (this.isEmptyList()) {
                Column() {
                  GlyphIcon({ glyphName: 'search', glyphSize: 24, glyphColor: C.tx4, glyphWeight: 1.4 })
                  Text(this.emptyTitle())
                    .fontSize(12.5)
                    .fontColor(C.tx2)
                    .margin({ top: 10 })
                  Text(this.emptySub())
                    .fontSize(10.5)
                    .fontColor(C.tx4)
                    .margin({ top: 5 })
                  Text(t('重置筛选'))
                    .fontSize(11.5)
                    .fontColor(C.tx)
                    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                    .backgroundColor(C.bg2)
                    .borderRadius(9)
                    .border({ width: 1, color: C.line })
                    .margin({ top: 14 })
                    .onClick(() => {
                      this.resetFilters();
                    })
                }
                .width('100%')
                .height(320)
                .justifyContent(FlexAlign.Center)
              } else {
                if (this.plain()) {
                  this.cardList()
                } else if (this.mode === 'series' && this.source !== 'local') {
                  this.seriesList()
                } else if (this.view === 'grid') {
                  this.gridList()
                } else {
                  this.rowList()
                }

                this.pager()
              }
            }
            .width('100%')
            .padding({ left: S.page, right: S.page, bottom: 100 })
          }
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .layoutWeight(1)
        .onRefreshing(() => {
          this.onPullRefresh();
        })
      }
      .width('100%')
      .height('100%')

      if (this.moreOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#01000000')
          .onClick(() => {
            this.moreOpen = false;
          })

        Column() {
          this.moreMenu()
        }
        .width('100%')
        .padding({ right: S.page, top: 61 })
        .alignItems(HorizontalAlign.End)
        .onClick(() => {
          this.moreOpen = false;
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
