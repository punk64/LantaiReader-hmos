import { C, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { ProgressMarks } from '../common/ProgressMarks';
import { CoverImage } from '../components/CoverImage';
import { Pill, ScreenHead } from '../components/Shell';
import { EmptyView, ErrorView, LoadingView, ProgressBar } from '../components/StateViews';
import { appStore } from '../model/AppStore';
import { BookItem, BookPage, BookQuery, emptyQuery, ReadListSummary } from '../model/LantaiModels';

import { t } from '../common/I18n';
@Component
struct ListBookRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('progressVer') @Watch('onMarks') progressVer: number = 0;
  @State marksTick: number = 0;
  @Prop book: BookItem = {} as BookItem;
  onOpen: () => void = () => {};

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
      CoverImage({ bookId: this.book.id, title: this.book.title, coverWidth: 38, coverHeight: 54, radius: 4 })
      Column({ space: 3 }) {
        Text(this.book.title)
          .fontSize(12)
          .fontColor(C.tx)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.book.authors.length > 0 ? this.book.authors : this.book.profile)
          .fontSize(9.5)
          .fontColor(C.tx4)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(F.progressLabel(this.page(), this.book.pages, this.done()))
        .fontSize(9.5)
        .fontColor(this.done() ? C.ok : C.tx4)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .onClick(() => {
      this.onOpen();
    })
  }
}

@Component
struct ReadListCard {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop item: ReadListSummary = {} as ReadListSummary;
  @Prop expanded: boolean = false;
  @Prop opening: boolean = false;
  @Prop books: BookItem[] = [];
  onTap: () => void = () => {};
  onOpenBook: (book: BookItem) => void = () => {};

  build() {
    Column() {
      Row({ space: 9 }) {
        Text(t('单'))
          .fontSize(13)
          .fontColor(C.acc2)
          .textAlign(TextAlign.Center)
          .width(34)
          .height(34)
          .backgroundColor(C.accBg)
          .borderRadius(10)
          .border({ width: 1, color: C.accLine })
        Column({ space: 3 }) {
          Text(this.item.name)
            .fontSize(14)
            .fontColor(C.tx)
            .letterSpacing(0.4)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(t(`${this.item.bookCount} 册`) + ' · ' + (this.item.ordered ? t('手动排序') : t('默认排序')) + (this.item.lastModified.length > 0 ? ' · ' + F.ago(this.item.lastModified) : ''))
            .fontSize(10)
            .fontColor(C.tx4)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Pill({ label: this.expanded ? t('收起') : t('展开'), tone: this.expanded ? 'acc' : 'mute' })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onTap();
      })

      if (this.item.summary.length > 0) {
        Text(this.item.summary)
          .fontSize(10.5)
          .fontColor(C.tx3)
          .lineHeight(17)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 9 })
      }

      if (this.expanded) {
        Divider()
          .color(C.line)
          .margin({ top: 11, bottom: 4 })
        if (this.opening) {
          Row() {
            LoadingView({ label: t('读取书单') })
          }
          .width('100%')
          .height(90)
        } else if (this.books.length === 0) {
          Text(t('这个书单里还没有可读的书'))
            .fontSize(10.5)
            .fontColor(C.tx4)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 18, bottom: 18 })
        } else {
          ForEach(this.books, (book: BookItem) => {
            ListBookRow({
              book: book,
              onOpen: () => {
                this.onOpenBook(book);
              }
            })
          }, (book: BookItem) => `${book.id}-${book.readPage}-${book.readCompleted}`)
        }
      }
    }
    .width('100%')
    .padding(13)
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: this.expanded ? C.accLine : C.line })
    .margin({ bottom: 10 })
  }
}

@Component
export struct ReadlistsPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State lists: ReadListSummary[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State openId: string = '';
  @State openBooks: BookItem[] = [];
  @State opening: boolean = false;

  aboutToAppear(): void {
    this.reload();
  }

  private totalBooks(): number {
    let total: number = 0;
    for (let index = 0; index < this.lists.length; index++) {
      total += this.lists[index].bookCount;
    }
    return total;
  }

  private async reload(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      this.lists = await appStore.api.readlists();
      this.loading = false;
    } catch (error) {
      this.error = (error as Error).message;
      this.lists = [];
      this.loading = false;
    }
  }

  private async toggle(item: ReadListSummary): Promise<void> {
    if (this.openId === item.id) {
      this.openId = '';
      this.openBooks = [];
      return;
    }
    this.openId = item.id;
    this.openBooks = [];
    this.opening = true;
    try {
      const query: BookQuery = emptyQuery();
      query.readListId = item.id;
      query.size = 60;
      query.sort = 'metadata.title,asc';
      const page: BookPage = await appStore.api.books(query);
      if (this.openId === item.id) {
        this.openBooks = page.items;
      }
    } catch (error) {
      if (this.openId === item.id) {
        this.openBooks = [];
      }
    }
    this.opening = false;
  }

  build() {
    Column() {
      ScreenHead({
        title: t('书单'),
        sub: this.lists.length > 0 ? t(`${this.lists.length} 个书单 · 合计 ${this.totalBooks()} 册`) : t('按阅读计划排序'),
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
              LoadingView({ label: t('读取书单') })
            }
            .width('100%')
            .height(280)
          } else if (this.error.length > 0) {
            Column() {
              ErrorView({ message: this.error, onRetry: () => {
                this.reload();
              } })
            }
            .width('100%')
            .height(280)
          } else if (this.lists.length === 0) {
            Column() {
              EmptyView({ title: t('还没有书单'), hint: t('在服务端网页版建立书单后，这里会自动出现'), glyph: 'list' })
            }
            .width('100%')
            .height(320)
          } else {
            ForEach(this.lists, (item: ReadListSummary) => {
              ReadListCard({
                item: item,
                expanded: this.openId === item.id,
                opening: this.opening && this.openId === item.id,
                books: this.openId === item.id ? this.openBooks : [],
                onTap: () => {
                  this.toggle(item);
                },
                onOpenBook: (book: BookItem) => {
                  appStore.selected = book;
                  this.nav.pushPathByName('book', null);
                }
              })
            }, (item: ReadListSummary) => `${item.id}-${item.bookCount}`)
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
