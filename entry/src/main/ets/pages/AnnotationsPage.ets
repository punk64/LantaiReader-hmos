import { C, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { CoverImage } from '../components/CoverImage';
import { GroupHead, ScreenHead, SegBar } from '../components/Shell';
import { EmptyView, ErrorView, LoadingView } from '../components/StateViews';
import { appStore } from '../model/AppStore';
import { BookAnnotation, BookItem, BookStat, ReadingStats } from '../model/LantaiModels';

import { t } from '../common/I18n';
interface NoteEntry {
  id: string;
  bookId: string;
  bookTitle: string;
  quote: string;
  note: string;
  locator: string;
  at: string;
  color: string;
  marker: string;
}

const MAX_BOOKS: number = 12;
const FALLBACK_COLOR: string = '#C9A24B';

function safeColor(raw: string): string {
  if (raw.length === 7 && raw.startsWith('#')) {
    return raw;
  }
  if (raw.length === 9 && raw.startsWith('#')) {
    return raw;
  }
  return FALLBACK_COLOR;
}

function shortLocator(href: string, fragment: string): string {
  const raw: string = fragment.length > 0 ? fragment : href;
  if (raw.length === 0) {
    return t('无定位');
  }
  const cut: number = raw.lastIndexOf('/');
  const tail: string = cut >= 0 ? raw.substring(cut + 1) : raw;
  return tail.length > 28 ? `${tail.substring(0, 28)}…` : tail;
}

@Component
struct HighlightCard {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop entry: NoteEntry = {} as NoteEntry;

  build() {
    Column({ space: 7 }) {
      Text(this.entry.quote.length > 0 ? this.entry.quote : t('（无文本片段）'))
        .fontSize(12.5)
        .fontColor(C.tx)
        .lineHeight(20)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row() {
        Text(`${this.entry.bookTitle} · ${this.entry.locator}`)
          .fontSize(9.5)
          .fontColor(C.tx4)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(F.ago(this.entry.at))
          .fontSize(9.5)
          .fontColor(C.tx4)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .backgroundColor(C.bg1)
    .borderRadius(R.s)
    .border({ width: { left: 3, top: 1, right: 1, bottom: 1 }, color: { left: safeColor(this.entry.color), top: C.line, right: C.line, bottom: C.line } })
    .margin({ bottom: 9 })
  }
}

@Component
struct BookmarkRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop entry: NoteEntry = {} as NoteEntry;

  build() {
    Row({ space: 12 }) {
      CoverImage({ bookId: this.entry.bookId, title: this.entry.bookTitle, coverWidth: 44, coverHeight: 62, radius: 4 })
      Column({ space: 4 }) {
        Text(this.entry.bookTitle)
          .fontSize(12.5)
          .fontColor(C.tx)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.entry.locator)
          .fontSize(10)
          .fontColor(C.tx3)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.entry.at.length > 0 ? t(`${F.ago(this.entry.at)} 添加`) : '')
          .fontSize(9.5)
          .fontColor(C.tx4)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }
}

@Component
struct NoteCard {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop entry: NoteEntry = {} as NoteEntry;

  build() {
    Column({ space: 7 }) {
      Text(`「${this.entry.quote}」`)
        .fontSize(12)
        .fontColor(C.acc2)
        .lineHeight(19)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(t(`注：${this.entry.note}`))
        .fontSize(11)
        .fontColor(C.tx2)
        .lineHeight(18)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row() {
        Text(`${this.entry.bookTitle} · ${this.entry.locator}`)
          .fontSize(9.5)
          .fontColor(C.tx4)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(F.ago(this.entry.at))
          .fontSize(9.5)
          .fontColor(C.tx4)
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(C.bg1)
    .borderRadius(R.s)
    .border({ width: 1, color: safeColor(this.entry.color) })
    .margin({ bottom: 9 })
  }
}

@Component
export struct AnnotationsPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State tab: number = 0;
  @State loading: boolean = true;
  @State error: string = '';
  @State entries: NoteEntry[] = [];
  @State scanned: number = 0;
  @State booksWithNotes: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  private ofTab(index: number): NoteEntry[] {
    const out: NoteEntry[] = [];
    for (let cursor = 0; cursor < this.entries.length; cursor++) {
      const entry: NoteEntry = this.entries[cursor];
      if (index === 2) {
        if (entry.note.length > 0) {
          out.push(entry);
        }
      } else if (index === 1) {
        if (entry.marker === 'BOOKMARK' && entry.note.length === 0) {
          out.push(entry);
        }
      } else if (entry.marker !== 'BOOKMARK' && entry.note.length === 0) {
        out.push(entry);
      }
    }
    return out;
  }

  private tabLabel(index: number): string {
    return `${index === 0 ? t('高亮') : (index === 1 ? t('书签') : t('笔记'))} ${this.ofTab(index).length}`;
  }

  private async reload(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const stats: ReadingStats = await appStore.api.readingStats();
      const sorted: BookStat[] = stats.books.slice().sort((left: BookStat, right: BookStat) => {
        return F.moment(right.lastReadAt) - F.moment(left.lastReadAt);
      });
      const head: BookStat[] = sorted.slice(0, MAX_BOOKS);
      const collected: NoteEntry[] = [];
      let books: number = 0;
      let fails: number = 0;
      for (let index = 0; index < head.length; index++) {
        const bookId: string = head[index].bookId;
        let title: string = '';
        try {
          const detail: BookItem = await appStore.api.book(bookId);
          title = detail.title;
        } catch (error) {
          title = t('已不在书库');
        }
        let list: BookAnnotation[] = [];
        try {
          list = await appStore.api.annotations(bookId);
        } catch (error) {
          list = [];
          fails += 1;
        }
        if (list.length > 0) {
          books += 1;
        }
        for (let cursor = 0; cursor < list.length; cursor++) {
          const item: BookAnnotation = list[cursor];
          collected.push({
            id: item.id,
            bookId: bookId,
            bookTitle: title,
            quote: item.highlight,
            note: item.note,
            locator: shortLocator(item.href, ''),
            at: item.createdDate,
            color: item.color,
            marker: item.marker
          });
        }
      }
      this.entries = collected;
      this.scanned = head.length;
      this.booksWithNotes = books;
      if (head.length > 0 && fails === head.length) {
        this.error = t('批注接口无响应，请检查服务器版本');
      }
      this.loading = false;
    } catch (error) {
      this.error = (error as Error).message;
      this.entries = [];
      this.loading = false;
    }
  }

  build() {
    Column() {
      ScreenHead({
        title: t('批注与书签'),
        sub: this.loading ? t('汇总中…') : t(`近 ${this.scanned} 本在读 · 共 ${this.entries.length} 条`),
        back: t('我的'),
        action: '⋯',
        onBack: () => {
          this.nav.pop();
        }
      })

      Scroll() {
        Column() {
          if (this.loading) {
            Column() {
              LoadingView({ label: t('汇总批注') })
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
            SegBar({
              options: [this.tabLabel(0), this.tabLabel(1), this.tabLabel(2)],
              current: this.tab,
              onPick: (index: number) => {
                this.tab = index;
              }
            })

            Column() {
              if (this.ofTab(this.tab).length === 0) {
                EmptyView({
                  title: this.tab === 0 ? t('没有高亮') : (this.tab === 1 ? t('没有书签') : t('没有笔记')),
                  hint: t('在阅读器里长按选段即可添加'),
                  glyph: this.tab === 1 ? 'bookmark' : 'marker'
                })
              } else {
                ForEach(this.ofTab(this.tab), (entry: NoteEntry) => {
                  if (this.tab === 0) {
                    HighlightCard({ entry: entry })
                  } else if (this.tab === 1) {
                    BookmarkRow({ entry: entry })
                  } else {
                    NoteCard({ entry: entry })
                  }
                }, (entry: NoteEntry) => `${entry.id}-${entry.at}-${this.tab}`)
              }
            }
            .width('100%')
            .margin({ top: 12 })

            GroupHead({ title: t('说明') })
            Column() {
              Text(t(`批注接口按书查询，本页汇总「最近读过的 ${this.scanned} 本」中 ${this.booksWithNotes} 本的记录。定位用文本三分段，字号变化后仍能找回；marker 含 HIGHLIGHT / UNDERLINE / BOOKMARK / COMMENT。`))
                .fontSize(9.5)
                .fontColor(C.tx4)
                .lineHeight(16)
                .width('100%')
            }
            .width('100%')
            .padding(13)
            .backgroundColor(C.bg1)
            .borderRadius(R.m)
            .border({ width: 1, color: C.line })
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
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
