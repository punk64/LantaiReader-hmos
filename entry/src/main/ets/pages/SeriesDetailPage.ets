import { C, FT, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { ProgressMarks } from '../common/ProgressMarks';
import { appStore } from '../model/AppStore';
import { BookItem, CollectionCard, emptyBook, emptySeries, isEbook, profileLabel, ReadListSummary, SeriesItem } from '../model/LantaiModels';
import { CoverImage } from '../components/CoverImage';
import { CoverProgress, FormatBadge } from '../components/BookViews';
import { GlyphIcon } from '../components/Icon';
import { ScreenHead } from '../components/Shell';
import { promptAction } from '@kit.ArkUI';

import { t, tf } from '../common/I18n';
interface SeriesPickOption {
  id: string;
  name: string;
  count: number;
  contains: boolean;
  ids: string[];
}

@Component
struct SeriesKv {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Row() {
      Text(this.label)
        .fontSize(11)
        .fontColor(C.tx4)
        .width(74)
      Text(this.value.length > 0 ? this.value : '—')
        .fontSize(11)
        .fontColor(C.tx2)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 7, bottom: 7 })
  }
}

@Component
struct VolumeRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('progressVer') @Watch('onMarks') progressVer: number = 0;
  @State marksTick: number = 0;
  @Prop book: BookItem = emptyBook();
  onTap: () => void = () => {};

  onMarks(): void {
    this.marksTick = this.marksTick + 1;
  }

  private page(): number {
    return ProgressMarks.pageOf(this.book.id, this.book.readPage);
  }

  private done(): boolean {
    return ProgressMarks.doneOf(this.book.id, this.book.readCompleted, this.page(), this.book.pages);
  }

  build() {
    Row({ space: 11 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        CoverImage({
          bookId: this.book.id,
          title: this.book.title,
          coverWidth: 40,
          coverHeight: 56,
          radius: 4
        })
        CoverProgress({
          percent: this.done() ? 100 : F.percent(this.page(), this.book.pages),
          barHeight: 3
        })
      }
      .width(40)
      .height(56)
      .borderRadius(4)
      .clip(true)

      Column({ space: 3 }) {
        Text(this.book.title)
          .fontSize(12.5)
          .fontColor(C.tx)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row({ space: 5 }) {
          FormatBadge({ label: profileLabel(this.book.profile) })
          if (this.book.number.length > 0) {
            FormatBadge({ label: `#${this.book.number}` })
          }
          if (this.book.pages > 0) {
            FormatBadge({ label: t(`${this.book.pages} 页`) })
          }
        }
        Text(F.progressLabel(this.page(), this.book.pages, this.done()))
          .fontSize(9.5)
          .fontColor(this.done() ? C.ok : C.tx4)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      GlyphIcon({ glyphName: 'next', glyphSize: 13, glyphColor: C.tx4 })
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
    .border({ width: { bottom: 1 }, color: C.line })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
struct SeriesCell {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop glyph: string = '';
  @Prop label: string = '';
  @Prop active: boolean = false;
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
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
export struct SeriesDetailPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('progressVer') @Watch('onMarks') progressVer: number = 0;
  @State marksTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State series: SeriesItem = emptySeries();
  @State books: BookItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State showInfo: boolean = false;
  @State showSummary: boolean = false;
  @State page: number = 0;
  @State sheet: string = '';
  @State options: SeriesPickOption[] = [];
  @State newName: string = '';
  @State busy: boolean = false;
  @State sheetNote: string = '';

  private pageSize(): number {
    return 24;
  }

  private pageCount(): number {
    return Math.max(1, Math.ceil(this.books.length / this.pageSize()));
  }

  private shownBooks(): BookItem[] {
    const current: number = Math.min(this.page, this.pageCount() - 1);
    const start: number = current * this.pageSize();
    return this.books.slice(start, start + this.pageSize());
  }

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const id: string = appStore.selectedSeriesId;
    if (id.length === 0) {
      this.loading = false;
      this.error = t('未选择系列');
      return;
    }
    try {
      this.series = await appStore.api.series(id);
      this.books = await appStore.api.seriesBooks(id);
      this.loading = false;
    } catch (error) {
      this.loading = false;
      this.error = (error as Error).message;
    }
  }

  private percent(): number {
    const total: number = this.totalCount();
    if (total <= 0) {
      return 0;
    }
    const touched: number = Math.min(total, this.doneCount() + this.readingCount());
    return Math.max(0, Math.round(touched * 100 / total));
  }

  private totalCount(): number {
    return this.series.booksCount > 0 ? this.series.booksCount : this.books.length;
  }

  private doneCount(): number {
    if (this.books.length === 0) {
      return this.series.readCount;
    }
    let count: number = 0;
    for (let index: number = 0; index < this.books.length; index++) {
      const book: BookItem = this.books[index];
      const page: number = ProgressMarks.pageOf(book.id, book.readPage);
      if (ProgressMarks.doneOf(book.id, book.readCompleted, page, book.pages)) {
        count += 1;
      }
    }
    return count;
  }

  private readingCount(): number {
    if (this.books.length === 0) {
      return this.series.inProgressCount;
    }
    let count: number = 0;
    for (let index: number = 0; index < this.books.length; index++) {
      const book: BookItem = this.books[index];
      const page: number = ProgressMarks.pageOf(book.id, book.readPage);
      if (page > 0 && !ProgressMarks.doneOf(book.id, book.readCompleted, page, book.pages)) {
        count += 1;
      }
    }
    return count;
  }

  onMarks(): void {
    this.marksTick = this.marksTick + 1;
  }

  private bookIds(): string[] {
    const out: string[] = [];
    for (let index = 0; index < this.books.length; index++) {
      out.push(this.books[index].id);
    }
    return out;
  }

  private failText(error: Error): string {
    const text: string = error.message;
    return text.indexOf('403') >= 0 ? t('当前账号无管理员权限') : text;
  }

  private async openCollections(): Promise<void> {
    this.sheet = 'collection';
    this.options = [];
    this.newName = '';
    this.sheetNote = t('读取中…');
    try {
      const list: CollectionCard[] = await appStore.api.collections();
      const sid: string = appStore.selectedSeriesId;
      const out: SeriesPickOption[] = [];
      for (let index = 0; index < list.length; index++) {
        const item: CollectionCard = list[index];
        out.push({
          id: item.id,
          name: item.name,
          count: item.seriesCount,
          contains: item.seriesIds.includes(sid),
          ids: item.seriesIds
        });
      }
      this.options = out;
      this.sheetNote = out.length === 0 ? t('服务端还没有系列合集，可在下方新建') : '';
    } catch (error) {
      this.sheetNote = t(`读取失败：${this.failText(error as Error)}`);
    }
  }

  private async openReadLists(): Promise<void> {
    this.sheet = 'readlist';
    this.options = [];
    this.newName = '';
    this.sheetNote = t('读取中…');
    try {
      const list: ReadListSummary[] = await appStore.api.readlists();
      const books: string[] = this.bookIds();
      const out: SeriesPickOption[] = [];
      for (let index = 0; index < list.length; index++) {
        const item: ReadListSummary = list[index];
        let all: boolean = books.length > 0;
        for (let cursor = 0; cursor < books.length; cursor++) {
          if (!item.bookIds.includes(books[cursor])) {
            all = false;
            break;
          }
        }
        out.push({
          id: item.id,
          name: item.name,
          count: item.bookCount,
          contains: all,
          ids: item.bookIds
        });
      }
      this.options = out;
      this.sheetNote = out.length === 0 ? t('服务端还没有书单，可在下方新建') : '';
    } catch (error) {
      this.sheetNote = t(`读取失败：${this.failText(error as Error)}`);
    }
  }

  private async pick(option: SeriesPickOption): Promise<void> {
    if (this.busy) {
      return;
    }
    if (option.contains) {
      promptAction.showToast({ message: this.sheet === 'collection' ? t('该系列已在此系列合集') : t('该系列已在此书单') });
      return;
    }
    this.busy = true;
    try {
      if (this.sheet === 'collection') {
        const merged: string[] = option.ids.concat([appStore.selectedSeriesId]);
        await appStore.api.updateCollectionSeries(option.id, merged);
        promptAction.showToast({ message: t(`已加入《${option.name}》`) });
      } else {
        const merged: string[] = option.ids.concat(this.bookIds());
        await appStore.api.updateReadListBooks(option.id, merged);
        promptAction.showToast({ message: t(`已把 ${this.books.length} 册加入《${option.name}》`) });
      }
      this.sheet = '';
    } catch (error) {
      promptAction.showToast({ message: t(`操作失败：${this.failText(error as Error)}`) });
    }
    this.busy = false;
  }

  private async createAndJoin(): Promise<void> {
    if (this.busy) {
      return;
    }
    const name: string = this.newName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: t('先填一个名称') });
      return;
    }
    this.busy = true;
    try {
      if (this.sheet === 'collection') {
        await appStore.api.createCollection(name, [appStore.selectedSeriesId]);
        promptAction.showToast({ message: t(`已新建系列合集《${name}》并加入`) });
      } else {
        const books: string[] = this.bookIds();
        await appStore.api.createReadList(name, books);
        promptAction.showToast({ message: t(`已新建书单《${name}》并加入 ${books.length} 册`) });
      }
      this.sheet = '';
    } catch (error) {
      promptAction.showToast({ message: t(`新建失败：${this.failText(error as Error)}`) });
    }
    this.busy = false;
  }

  private coverId(): string {
    return this.books.length > 0 ? this.books[0].id : '';
  }

  private coverTitle(): string {
    return this.books.length > 0 ? this.books[0].title : this.series.name;
  }

  private nextBook(): BookItem | null {
    for (let index = 0; index < this.books.length; index++) {
      const book: BookItem = this.books[index];
      const page: number = ProgressMarks.pageOf(book.id, book.readPage);
      if (page > 0 && !ProgressMarks.doneOf(book.id, book.readCompleted, page, book.pages)) {
        return book;
      }
    }
    for (let index = 0; index < this.books.length; index++) {
      const book: BookItem = this.books[index];
      const page: number = ProgressMarks.pageOf(book.id, book.readPage);
      if (!ProgressMarks.doneOf(book.id, book.readCompleted, page, book.pages)) {
        return book;
      }
    }
    return this.books.length > 0 ? this.books[0] : null;
  }

  private actionLabel(): string {
    const book: BookItem | null = this.nextBook();
    if (book === null) {
      return t('开始阅读');
    }
    const number: string = book.number.length > 0 ? book.number : `${this.books.indexOf(book) + 1}`;
    return ProgressMarks.pageOf(book.id, book.readPage) > 0 ? t(`继续第 ${number} 册`) : t(`开始第 ${number} 册`);
  }

  private openBook(book: BookItem): void {
    appStore.selected = book;
    this.nav.pushPathByName('book', null);
  }

  @Builder
  crumb() {
    Row({ space: 4 }) {
      Text(t('首页'))
        .fontSize(10.5)
        .fontColor(C.tx3)
        .onClick(() => {
          this.nav.pop();
        })
      GlyphIcon({ glyphName: 'next', glyphSize: 11, glyphColor: C.tx4 })
      Text(t('系列'))
        .fontSize(10.5)
        .fontColor(C.tx3)
      GlyphIcon({ glyphName: 'next', glyphSize: 11, glyphColor: C.tx4 })
      Text(this.series.name)
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
        bookId: this.coverId(),
        title: this.coverTitle(),
        coverWidth: 104,
        coverHeight: 145,
        radius: 8
      })

      Column() {
        Row({ space: 5 }) {
          FormatBadge({ label: this.series.status === 'ENDED' ? t('已完结') : this.series.status === 'ONGOING' ? t('连载中') : t('状态未知') })
          FormatBadge({ label: t(`${this.series.booksCount} 册`) })
        }
        .width('100%')

        Text(this.series.name)
          .fontSize(18)
          .fontFamily(FT.disp)
          .letterSpacing(0.6)
          .fontColor(C.tx)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 8 })

        Text(this.series.publisher.length > 0 ? this.series.publisher : this.series.genres.join(' / '))
          .fontSize(11)
          .fontColor(C.tx3)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 3 })

        Blank()

        Row({ space: 11 }) {
          Stack() {
            Progress({ value: this.percent(), total: 100, type: ProgressType.Ring })
              .width(46)
              .height(46)
              .color(C.acc)
              .backgroundColor(C.bg4)
              .style({ strokeWidth: 4 })
            Text(`${this.percent()}%`)
              .fontSize(10)
              .fontFamily(FT.mono)
              .fontColor(C.acc2)
          }
          .width(46)
          .height(46)

          Column({ space: 3 }) {
            Text(t(`已读 ${this.doneCount()} / ${this.totalCount()} 册`))
              .fontSize(10.5)
              .fontColor(C.tx2)
              .width('100%')
            Text(this.readingCount() > 0 ? t(`在读 ${this.readingCount()} 册`) : t('暂无在读'))
              .fontSize(9.5)
              .fontColor(C.tx4)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .height(145)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  summaryBox() {
    if (this.series.summary.length > 0) {
      Column() {
        Text(this.series.summary)
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
          GlyphIcon({ glyphName: 'book', glyphSize: 15, glyphColor: C.bg })
          Text(this.actionLabel())
            .fontSize(12.5)
            .fontColor(C.bg)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
        }
        .layoutWeight(1.6)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(C.acc)
        .borderRadius(10)
        .onClick(() => {
          const book: BookItem | null = this.nextBook();
          if (book !== null) {
            this.openBook(book);
          }
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
          const book: BookItem | null = this.nextBook();
          if (book === null) {
            return;
          }
          appStore.readerIncognito = true;
          appStore.readerBookId = book.id;
          appStore.readerTitle = book.title;
          appStore.readerChapter = Math.max(1, ProgressMarks.pageOf(book.id, book.readPage));
          this.nav.pushPathByName(isEbook(book.profile) ? 'reader' : 'comic', null);
        })
      }
      .width('100%')

      Row({ space: 6 }) {
        SeriesCell({
          glyph: 'info',
          label: t('系列信息'),
          active: this.showInfo,
          onTap: () => {
            this.showInfo = !this.showInfo;
          }
        })
        SeriesCell({
          glyph: 'collection',
          label: t('加入系列合集'),
          onTap: () => {
            this.openCollections();
          }
        })
        SeriesCell({
          glyph: 'readlist',
          label: t('加入书单'),
          onTap: () => {
            this.openReadLists();
          }
        })
      }
      .width('100%')
      .margin({ top: 7 })
    }
    .width('100%')
    .padding(9)
    .backgroundColor(C.bg2)
    .borderRadius(R.l)
    .border({ width: 1, color: C.line })
    .margin({ top: 12 })
  }

  @Builder
  volumeList() {
    Row({ space: 8 }) {
      Text(t('分册'))
        .fontSize(16)
        .fontFamily(FT.disp)
        .letterSpacing(1)
        .fontColor(C.tx)
      Text(`${this.books.length}`)
        .fontSize(10)
        .fontFamily(FT.mono)
        .fontColor(C.tx4)
      Blank()
    }
    .width('100%')
    .margin({ top: 22, bottom: 11 })

    Column() {
      if (this.books.length === 0) {
        Text(this.loading ? t('分册读取中…') : t('该系列暂无分册'))
          .fontSize(11)
          .fontColor(C.tx4)
          .padding({ top: 14, bottom: 14 })
      } else {
        ForEach(this.shownBooks(), (book: BookItem) => {
          VolumeRow({
            book: book,
            onTap: () => {
              this.openBook(book);
            }
          })
        }, (book: BookItem) => book.id)

        Row({ space: 8 }) {
          Row() {
            Text(t('‹ 上一页'))
              .fontSize(10.5)
              .fontColor(this.page <= 0 ? C.tx4 : C.tx2)
          }
          .layoutWeight(1)
          .height(30)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(C.bg3)
          .borderRadius(8)
          .border({ width: 1, color: C.line })
          .opacity(this.page <= 0 ? 0.45 : 1)
          .onClick(() => {
            if (this.page > 0) {
              this.page--;
            }
          })

          Text(t(`第 ${Math.min(this.page + 1, this.pageCount())} / ${this.pageCount()} 页`))
            .fontSize(9.5)
            .fontFamily(FT.mono)
            .fontColor(C.tx4)

          Row() {
            Text(t('下一页 ›'))
              .fontSize(10.5)
              .fontColor(this.page >= this.pageCount() - 1 ? C.tx4 : C.tx2)
          }
          .layoutWeight(1)
          .height(30)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(C.bg3)
          .borderRadius(8)
          .border({ width: 1, color: C.line })
          .opacity(this.page >= this.pageCount() - 1 ? 0.45 : 1)
          .onClick(() => {
            if (this.page < this.pageCount() - 1) {
              this.page++;
            }
          })
        }
        .width('100%')
        .margin({ top: 8, bottom: 10 })
      }
    }
    .width('100%')
    .padding({ left: 13, right: 13 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
  }

  @Builder
  infoCard() {
    Column() {
      Text(t('系列信息'))
        .fontSize(12)
        .fontColor(C.tx)
        .width('100%')
        .margin({ bottom: 6 })
      Divider().color(C.line).strokeWidth(1)
      SeriesKv({ label: t('系列名'), value: this.series.name })
      Divider().color(C.line).strokeWidth(1)
      SeriesKv({ label: t('出版社'), value: this.series.publisher })
      Divider().color(C.line).strokeWidth(1)
      SeriesKv({ label: t('语言'), value: this.series.language })
      Divider().color(C.line).strokeWidth(1)
      SeriesKv({ label: t('分类'), value: this.series.genres.join(' / ') })
      Divider().color(C.line).strokeWidth(1)
      SeriesKv({ label: t('标签'), value: this.series.tags.join(' · ') })
      Divider().color(C.line).strokeWidth(1)
      SeriesKv({
        label: t('状态'),
        value: this.series.status === 'ENDED' ? t('已完结') : this.series.status === 'ONGOING' ? t('连载中') : this.series.status
      })
      Divider().color(C.line).strokeWidth(1)
      SeriesKv({ label: t('总册数'), value: this.series.totalBookCount > 0 ? `${this.series.totalBookCount}` : `${this.series.booksCount}` })
      Divider().color(C.line).strokeWidth(1)
      SeriesKv({ label: t('入库时间'), value: F.stamp(this.series.created) })
      Divider().color(C.line).strokeWidth(1)
      SeriesKv({ label: t('最近更新'), value: F.stamp(this.series.lastModified) })
    }
    .width('100%')
    .padding(13)
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .margin({ top: 12 })
  }

  @Builder
  sheetLayer() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#99000000')
        .onClick(() => {
          this.sheet = '';
        })

      Column({ space: 10 }) {
        Row() {
          Text(this.sheet === 'collection' ? t('加入系列合集') : t('加入书单'))
            .fontSize(14)
            .fontFamily(FT.disp)
            .letterSpacing(0.8)
            .fontColor(C.tx)
          Blank()
          Text(t('关闭'))
            .fontSize(11)
            .fontColor(C.tx3)
            .onClick(() => {
              this.sheet = '';
            })
        }
        .width('100%')

        Text(this.sheet === 'collection' ? t('选中后把本系列加进该系列合集')
          : t(`选中后把本系列 ${this.books.length} 册加进该书单`))
          .fontSize(10)
          .fontColor(C.tx4)
          .width('100%')

        if (this.sheetNote.length > 0) {
          Text(this.sheetNote)
            .fontSize(10.5)
            .fontColor(C.tx3)
            .width('100%')
        }

        Scroll() {
          Column() {
            ForEach(this.options, (item: SeriesPickOption) => {
              Row({ space: 9 }) {
                Column({ space: 2 }) {
                  Text(item.name)
                    .fontSize(12)
                    .fontColor(C.tx)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  Text(tf('{0} {1}', [`${item.count}`, this.sheet === 'collection' ? t('个系列') : t('册')]))
                    .fontSize(9.5)
                    .fontColor(C.tx4)
                    .width('100%')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(item.contains ? t('已在其中') : t('加入'))
                  .fontSize(10.5)
                  .fontColor(item.contains ? C.tx4 : C.acc2)
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .border({ width: { bottom: 1 }, color: C.line })
              .onClick(() => {
                this.pick(item);
              })
            }, (item: SeriesPickOption) => `${item.id}-${item.contains}`)
          }
          .width('100%')
        }
        .constraintSize({ maxHeight: 280 })
        .scrollBar(BarState.Off)

        Row({ space: 8 }) {
          TextInput({ placeholder: t('新建名称'), text: this.newName })
            .height(36)
            .layoutWeight(1)
            .fontSize(11.5)
            .backgroundColor(C.bg3)
            .borderRadius(9)
            .onChange((value: string) => {
              this.newName = value;
            })
          Text(this.sheet === 'collection' ? t('新建系列合集') : t('新建书单'))
            .fontSize(11)
            .fontColor(C.bg)
            .height(36)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.busy ? C.bg3 : C.acc)
            .borderRadius(9)
            .onClick(() => {
              this.createAndJoin();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: S.page, right: S.page, top: 16, bottom: 22 })
      .backgroundColor(C.bg1)
      .borderRadius({ topLeft: R.l, topRight: R.l })
      .border({ width: { top: 1 }, color: C.line })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
    Column() {
      ScreenHead({
        title: t('系列详情'),
        back: t('首页'),
        onBack: () => {
          this.nav.pop();
        }
      })

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
            this.dock()
            this.volumeList()
            if (this.showInfo) {
              this.infoCard()
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

      if (this.sheet.length > 0) {
        this.sheetLayer()
      }
    }
    .width('100%')
    .height('100%')
  }
}
