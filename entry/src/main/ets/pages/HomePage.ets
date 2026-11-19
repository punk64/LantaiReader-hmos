import { C, FT, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { ProgressMarks } from '../common/ProgressMarks';
import { appStore } from '../model/AppStore';
import { BookItem, BookQuery, emptyHome, emptyQuery, HomePayload, isEbook } from '../model/LantaiModels';
import { CoverImage } from '../components/CoverImage';
import { CoverProgress } from '../components/BookViews';
import { GlyphIcon } from '../components/Icon';
import { ErrorView, ProgressBar, SectionHead } from '../components/StateViews';
import { HomeSkeleton } from '../components/Skeletons';
import { ScreenHead } from '../components/Shell';

import { t } from '../common/I18n';
@Component
struct ShelfCard {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop bookId: string = '';
  @Prop title: string = '';
  @Prop fmt: string = '';
  @Prop percent: number = 0;
  onTap: () => void = () => {};

  build() {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        CoverImage({
          bookId: this.bookId,
          title: this.title,
          coverWidth: 82,
          coverHeight: 115,
          radius: 7
        })
        CoverProgress({ percent: this.percent, barHeight: 3 })
      }
      .width(82)
      .height(115)
      .borderRadius(7)
      .clip(true)

      Text(this.title)
        .fontSize(11)
        .fontColor(C.tx)
        .lineHeight(15)
        .maxLines(2)
        .height(30)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })

      Row() {
        Text(this.fmt)
          .fontSize(9)
          .fontFamily(FT.mono)
          .fontColor(C.tx4)
        Blank()
        Text(`${this.percent}%`)
          .fontSize(9)
          .fontFamily(FT.mono)
          .fontColor(C.acc2)
      }
      .width('100%')
      .height(13)
      .margin({ top: 4 })
    }
    .width(82)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
struct HomeShelf {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('progressVer') @Watch('onMarks') progressVer: number = 0;
  @State marksTick: number = 0;
  @Prop list: BookItem[] = [];
  @Prop idPrefix: string = '';
  onTap: (book: BookItem) => void = () => {};
  @State offsetX: number = 0;
  @State contentW: number = 0;
  @State viewW: number = 0;
  @State railOn: boolean = true;
  private downX: number = 0;
  private downY: number = 0;
  private moved: boolean = false;
  private railTimer: number = -1;
  private shelfScroller: Scroller = new Scroller();

  private num(v: Length): number {
    return typeof v === 'number' ? v as number : parseFloat(`${v}`);
  }

  onMarks(): void {
    this.marksTick = this.marksTick + 1;
  }

  private pct(book: BookItem): number {
    const page: number = ProgressMarks.pageOf(book.id, book.readPage);
    if (ProgressMarks.doneOf(book.id, book.readCompleted, page, book.pages)) {
      return 100;
    }
    return F.percent(page, book.pages);
  }

  private onCardTouch(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }
    const x: number = event.touches[0].windowX;
    const y: number = event.touches[0].windowY;
    if (event.type === TouchType.Down) {
      this.downX = x;
      this.downY = y;
      this.moved = false;
    } else if (event.type === TouchType.Move) {
      if (Math.abs(x - this.downX) > 8 || Math.abs(y - this.downY) > 8) {
        this.moved = true;
      }
    }
  }

  private railW(): number {
    const track: number = this.viewW - S.page * 2;
    if (this.contentW <= this.viewW + 2 || track <= 0) {
      return 0;
    }
    return track;
  }

  private thumbW(track: number): number {
    const raw: number = track * this.viewW / this.contentW;
    return Math.max(30, Math.min(track, raw));
  }

  private thumbX(track: number, thumb: number): number {
    const span: number = this.contentW - this.viewW;
    if (span <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(track - thumb, this.offsetX / span * (track - thumb)));
  }

  private bumpRail(): void {
    this.railOn = true;
    if (this.railTimer !== -1) {
      clearTimeout(this.railTimer);
    }
    this.railTimer = setTimeout(() => {
      this.railTimer = -1;
      this.railOn = false;
    }, 900);
  }

  aboutToAppear(): void {
    this.bumpRail();
  }

  aboutToDisappear(): void {
    if (this.railTimer !== -1) {
      clearTimeout(this.railTimer);
      this.railTimer = -1;
    }
  }

  @Builder
  railLayer() {
    if (this.railW() > 0) {
      Column() {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(2)
            .borderRadius(1)
            .backgroundColor(C.line)
          Row()
            .width(this.thumbW(this.railW()))
            .height(2)
            .borderRadius(1)
            .backgroundColor(C.acc)
            .translate({ x: this.thumbX(this.railW(), this.thumbW(this.railW())) })
        }
        .width(this.railW())
        .height(2)
      }
      .width(this.railW())
      .height(2)
      .margin({ bottom: 3 })
      .opacity(this.railOn ? 1 : 0.45)
      .animation({ duration: 220, curve: Curve.EaseOut })
      .hitTestBehavior(HitTestMode.None)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll(this.shelfScroller) {
        Row({ space: 10 }) {
          ForEach(this.list, (item: BookItem) => {
            ShelfCard({
              bookId: item.id,
              title: item.title,
              fmt: profileLabel(item.profile),
              percent: this.pct(item),
              onTap: () => {
                if (!this.moved) {
                  this.onTap(item);
                }
              }
            })
              .onTouch((event: TouchEvent) => {
                this.onCardTouch(event);
              })
          }, (item: BookItem) => `${this.idPrefix}-${item.id}`)
        }
        .constraintSize({ minWidth: '100%' })
        .justifyContent(FlexAlign.Start)
        .padding({ left: S.page, right: S.page, bottom: 6 })
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.contentW = this.num(newArea.width);
        })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .onScroll(() => {
        const off: OffsetResult = this.shelfScroller.currentOffset();
        this.offsetX = off.xOffset;
        this.bumpRail();
      })
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.viewW = this.num(newArea.width);
      })

      this.railLayer()
    }
    .width('100%')
  }
}

@Component
struct HeroCard {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop bookId: string = '';
  @Prop title: string = '';
  @Prop sub: string = '';
  @Prop line: string = '';
  @Prop percent: number = 0;
  @Prop moment: string = '';
  onTap: () => void = () => {};

  build() {
    Column() {
      Row({ space: 6 }) {
        Circle().width(5).height(5).fill(C.ok)
        Text(t(`继续阅读 · ${this.moment}`))
          .fontSize(10)
          .fontColor(C.acc2)
          .letterSpacing(0.5)
          .maxLines(1)
      }
      .width('100%')

      Row({ space: 14 }) {
        CoverImage({
          bookId: this.bookId,
          title: this.title,
          coverWidth: 88,
          coverHeight: 124,
          radius: 6
        })

        Column() {
          Text(this.title)
            .fontSize(19)
            .fontFamily(FT.disp)
            .letterSpacing(1)
            .lineHeight(25)
            .fontColor(C.tx)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.sub)
            .fontSize(11.5)
            .fontColor(C.tx3)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 3 })

          Blank()

          Text(this.line)
            .fontSize(11)
            .fontColor(C.tx3)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ bottom: 7 })

          ProgressBar({ percent: this.percent })
            .margin({ bottom: 8 })

          Row({ space: 6 }) {
            GlyphIcon({ glyphName: 'book', glyphSize: 14, glyphColor: C.onAcc })
            Text(t('继续阅读'))
              .fontSize(12.5)
              .fontColor(C.onAcc)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .height(32)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(C.acc)
          .borderRadius(9)
        }
        .layoutWeight(1)
        .height(124)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ top: 13 })
    }
    .width('100%')
    .padding(14)
    .linearGradient({
      angle: 140,
      colors: [[C.bg2, 0], [C.bg1, 1]]
    })
    .borderRadius(R.l)
    .border({ width: 1, color: C.accLine })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
export struct HomePage {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('progressVer') @Watch('onMarks') progressVer: number = 0;
  @State marksTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State error: string = '';
  @State home: HomePayload = emptyHome();
  @State unread: BookItem[] = [];
  @State updated: BookItem[] = [];
  @State heroBook: BookItem | null = null;
  onLogout: () => void = () => {};

  aboutToAppear(): void {
    this.loadUnread();
    this.loadUpdated();
    this.reload();
  }

  onMarks(): void {
    this.marksTick = this.marksTick + 1;
  }

  private pct(book: BookItem): number {
    const page: number = ProgressMarks.pageOf(book.id, book.readPage);
    if (ProgressMarks.doneOf(book.id, book.readCompleted, page, book.pages)) {
      return 100;
    }
    return F.percent(page, book.pages);
  }

  private async reload(): Promise<void> {
    this.error = '';
    const first: boolean = this.home.added.length === 0;
    if (first) {
      this.loading = true;
    }
    try {
      const payload: HomePayload = await appStore.api.home(12);
      this.home = payload;
      this.heroBook = this.pickHero(payload);
      this.loading = false;
      if (!first) {
        this.loadUnread();
        this.loadUpdated();
      }
    } catch (error) {
      this.loading = false;
      const message: string = (error as Error).message;
      if (message.indexOf(t('会话')) >= 0) {
        this.onLogout();
        return;
      }
      this.error = message;
    } finally {
      this.refreshing = false;
    }
  }

  private loadUnread(): void {
    appStore.api.wantToRead(0, 12)
      .then((page) => {
        this.unread = page.items;
      })
      .catch(() => {
        this.unread = [];
      });
  }

  private loadUpdated(): void {
    const query: BookQuery = emptyQuery();
    query.size = 12;
    query.sort = 'lastModified,desc';
    appStore.api.books(query)
      .then((page) => {
        this.updated = page.items;
      })
      .catch(() => {
        this.updated = [];
      });
  }

  private openDetail(book: BookItem): void {
    appStore.selected = book;
    this.nav.pushPathByName('book', null);
  }

  private openReader(book: BookItem): void {
    appStore.selected = book;
    appStore.readerIncognito = false;
    appStore.readerBookId = book.id;
    appStore.readerTitle = book.title;
    appStore.readerChapter = Math.max(1, ProgressMarks.pageOf(book.id, book.readPage));
    if (!isEbook(book.profile)) {
      this.nav.pushPathByName('comic', null);
      return;
    }
    this.nav.pushPathByName('reader', null);
  }

  private pickHero(payload: HomePayload): BookItem | null {
    if (payload.continueReading.length > 0) {
      return payload.continueReading[0];
    }
    if (payload.recentRead.length > 0) {
      return payload.recentRead[0];
    }
    return null;
  }

  private heroSub(book: BookItem): string {
    const parts: string[] = [];
    if (book.authors.length > 0) {
      parts.push(book.authors);
    }
    if (book.volume.length > 0) {
      parts.push(book.volume);
    }
    if (parts.length === 0) {
      parts.push(book.seriesTitle.length > 0 ? book.seriesTitle : profileLabel(book.profile));
    }
    return parts.join(' · ');
  }

  private heroLine(book: BookItem): string {
    const page: number = ProgressMarks.pageOf(book.id, book.readPage);
    const at: string = page > 0 ? t(`第 ${page} 页`) : (book.seriesTitle.length > 0 ? book.seriesTitle : t('未开始'));
    return t(`${at} · 已读 ${this.pct(book)}%`);
  }

  @Builder
  topBar() {
    ScreenHead({ brand: true })
  }

  @Builder
  body() {
    Refresh({ refreshing: $$this.refreshing }) {
      Scroll() {
        Column() {
          Column() {
            if (this.heroBook !== null) {
              HeroCard({
                bookId: this.heroBook!.id,
                title: this.heroBook!.title,
                sub: this.heroSub(this.heroBook!),
                line: this.heroLine(this.heroBook!),
                percent: this.pct(this.heroBook!),
                moment: F.ago(this.heroBook!.readDate),
                onTap: () => {
                  this.openReader(this.heroBook!);
                }
              })
            }

            if (this.home.recentRead.length > 0) {
              SectionHead({
                title: t('最近在读'),
                meta: t(`${this.home.recentRead.length} 册`)
              })
            }
          }
          .width('100%')
          .padding({ left: S.page, right: S.page })
          .margin({ top: 4 })

          if (this.home.recentRead.length > 0) {
            HomeShelf({
              list: this.home.recentRead,
              idPrefix: 'read',
              onTap: (item: BookItem) => {
                this.openDetail(item);
              }
            })
          }

          Column() {
            SectionHead({
              title: t('待读'),
              meta: this.unread.length > 0 ? t(`${this.unread.length} 册`) : ''
            })
          }
          .width('100%')
          .padding({ left: S.page, right: S.page })

          if (this.unread.length > 0) {
            HomeShelf({
              list: this.unread,
              idPrefix: 'want',
              onTap: (item: BookItem) => {
                this.openDetail(item);
              }
            })
          } else {
            Column() {
              GlyphIcon({ glyphName: 'book', glyphSize: 22, glyphColor: C.tx4, glyphWeight: 1.4 })
              Text(t('暂时没有待读的书'))
                .fontSize(12)
                .fontColor(C.tx2)
                .margin({ top: 8 })
              Text(t('在书籍详情点「加入待读」'))
                .fontSize(10.5)
                .fontColor(C.tx4)
                .margin({ top: 4 })
            }
            .width('100%')
            .padding({ top: 24, bottom: 24 })
            .backgroundColor(C.bg1)
            .borderRadius(R.m)
            .border({ width: 1, color: C.line })
            .margin({ left: S.page, right: S.page, top: 0 })
          }

          Column() {
            if (this.home.added.length > 0) {
              SectionHead({
                title: t('最近添加'),
                meta: t(`${this.home.added.length} 册`)
              })
            }
          }
          .width('100%')
          .padding({ left: S.page, right: S.page })

          if (this.home.added.length > 0) {
            HomeShelf({
              list: this.home.added,
              idPrefix: 'added',
              onTap: (item: BookItem) => {
                this.openDetail(item);
              }
            })
          }

          Column() {
            if (this.updated.length > 0) {
              SectionHead({
                title: t('最近更新'),
                meta: t(`${this.updated.length} 册`)
              })
            }
          }
          .width('100%')
          .padding({ left: S.page, right: S.page })

          if (this.updated.length > 0) {
            HomeShelf({
              list: this.updated,
              idPrefix: 'updated',
              onTap: (item: BookItem) => {
                this.openDetail(item);
              }
            })
          }
        }
        .width('100%')
        .padding({ bottom: 100 })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height('100%')
    }
    .onRefreshing(() => {
      this.reload();
    })
    .width('100%')
    .layoutWeight(1)
    .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut }))
  }

  build() {
    Column() {
      this.topBar()

      if (this.loading) {
        HomeSkeleton()
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      } else if (this.error.length > 0) {
        ErrorView({ message: this.error, onRetry: () => {
          this.reload();
        } })
      } else {
        this.body()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}

function profileLabel(profile: string): string {
  return profile.length > 0 ? profile : '—';
}
