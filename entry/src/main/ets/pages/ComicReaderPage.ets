import { image } from '@kit.ImageKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { C, FT, R } from '../common/Theme';
import { WindowFx } from '../common/WindowFx';
import { appStore } from '../model/AppStore';
import { offlinePage } from '../net/OfflineCache';
import { ArchiveBook, comicArchive } from '../net/ComicArchive';
import { GlyphIcon } from '../components/Icon';
import { PrefKeys, Prefs } from '../model/Prefs';
import { ImageOps } from '../common/ImageOps';
import { ReaderGuide } from '../components/ReaderGuide';
import { readingTracker } from '../net/ReadingSession';
import { ProgressMarks } from '../common/ProgressMarks';
import { LocalStore } from '../net/LocalStore';

import { t, tf } from '../common/I18n';
interface ComicTool {
  label: string;
  icon: string;
}

function tools(): ComicTool[] {
  return [
    { label: t('缩略图'), icon: 'thumbs' },
    { label: t('画质与版式'), icon: 'settings' },
    { label: t('书签'), icon: 'bookmark' }
  ];
}

class PageSource implements IDataSource {
  private items: number[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): number {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  reset(total: number): void {
    const next: number[] = [];
    for (let n: number = 1; n <= total; n++) {
      next.push(n);
    }
    this.items = next;
    for (let index: number = 0; index < this.listeners.length; index++) {
      this.listeners[index].onDataReloaded();
    }
  }
}

@Component
export struct ComicReaderPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State bar: boolean = true;
  @State @Watch('onPageTick') page: number = 1;
  @State thumbs: boolean = false;
  @State bookmarked: boolean = false;
  @State total: number = 0;
  @State title: string = '';
  @State incognito: boolean = false;
  @State pixmap: image.PixelMap | undefined = undefined;
  @State pixmap2: image.PixelMap | undefined = undefined;
  @State loading: boolean = false;
  @State failed: string = '';
  @State failed2: string = '';
  @State mode: string = 'paged';
  @State panel: boolean = false;
  @State crop: boolean = false;
  @State enhance: boolean = false;
  @State qualityIndex: number = 2;
  @State zoom: number = 1;
  @State panOffX: number = 0;
  @State stripVersion: number = 0;
  @State safeTop: number = 0;
  @State safeBottom: number = 0;
  @State breath: number = 0.32;
  @State @Watch('onGuide') guideOpen: boolean = false;
  @State guideStep: number = 0;
  @State guideNeedKey: string = '';
  @State sliderPage: number = 0;
  @State topRect: string = '';
  @State bottomRect: string = '';
  @State progressRect: string = '';
  @State stageW: number = 0;
  private source: PageSource = new PageSource();
  private thumbSource: PageSource = new PageSource();
  private thumbScroller: Scroller = new Scroller();
  private thumbIdle: number = -1;
  private scroller: Scroller = new Scroller();
  private scrollTarget: number = 0;
  private pinchBase: number = 1;
  private panBaseX: number = 0;
  private panLastX: number = 0;
  private tDownX: number = 0;
  private tDownY: number = 0;
  private tMove: number = 0;
  private swipeTurn: boolean = false;
  private bookId: string = '';
  private localId: string = '';
  private archive: ArchiveBook | null = null;
  private cache: Map<number, image.PixelMap> = new Map<number, image.PixelMap>();
  private guard: number = -1;
  private progressAt: number = 0;
  private barTimer: number = -1;

  onPageTick(): void {
    AppStorage.setOrCreate('comicCurPage', this.page);
    readingTracker.track(this.page);
    this.markLocal();
    this.pushProgress();
  }

  private markLocal(): void {
    if (this.incognito) {
      return;
    }
    if (this.localId.length > 0) {
      ProgressMarks.put(this.localId, this.page, this.total);
      return;
    }
    if (this.bookId.length > 0) {
      const selected = appStore.selected;
      const done: boolean = selected !== null && selected.id === this.bookId ? selected.readCompleted : false;
      ProgressMarks.put(this.bookId, this.page, this.total, done);
    }
  }

  private saveLocal(): void {
    if (this.localId.length === 0) {
      return;
    }
    const id: string = this.localId;
    const page: number = this.page;
    const ratio: number = this.total > 0 ? page / this.total : 0;
    ProgressMarks.put(id, page, this.total);
    LocalStore.saveProgress(id, page, ratio).catch(() => {
    });
    ProgressMarks.flush();
  }

  private flushProgress(): void {
    if (this.incognito || this.bookId.length === 0 || this.page <= 0) {
      return;
    }
    this.progressAt = Date.now();
    appStore.api.savePage(this.bookId, this.page).catch(() => {
    });
    ProgressMarks.flush();
  }

  private holdThumbs(): void {
    if (AppStorage.get<boolean>('comicThumbBusy') !== true) {
      AppStorage.setOrCreate('comicThumbBusy', true);
    }
    if (this.thumbIdle >= 0) {
      clearTimeout(this.thumbIdle);
    }
    this.thumbIdle = setTimeout(() => {
      this.thumbIdle = -1;
      AppStorage.setOrCreate('comicThumbBusy', false);
    }, 260);
  }

  private releaseThumbs(): void {
    if (this.thumbIdle >= 0) {
      clearTimeout(this.thumbIdle);
      this.thumbIdle = -1;
    }
    AppStorage.setOrCreate('comicThumbBusy', false);
  }

  private focusThumbs(): void {
    this.releaseThumbs();
    const target: number = Math.max(0, this.page - 3);
    setTimeout(() => {
      try {
        this.thumbScroller.scrollToIndex(target, false, ScrollAlign.START);
      } catch (error) {
        hilog.warn(0x0000, 'LantaiThumb', 'scrollToIndex failed: %{public}s',
          (error as Error).message);
      }
    }, 80);
  }

  private pickPage(item: number): void {
    this.jumpTo(item);
  }

  private pushProgress(): void {
    if (this.incognito || this.bookId.length === 0) {
      return;
    }
    const now: number = Date.now();
    if (now - this.progressAt < 2000) {
      return;
    }
    this.progressAt = now;
    appStore.api.savePage(this.bookId, this.page).catch(() => {
    });
  }

  aboutToAppear(): void {
    appStore.backHook = () => this.onBack();
    AppStorage.setOrCreate('comicThumbBusy', false);
    AppStorage.setOrCreate('comicCurPage', this.page);
    const modeIndex: number = Prefs.int(PrefKeys.cmMode, 0);
    this.mode = modeIndex === 2 ? 'scroll' : (modeIndex === 1 ? 'spread' : 'paged');
    this.swipeTurn = modeIndex === 3;
    this.qualityIndex = Prefs.int(PrefKeys.cmQuality, 2);
    this.applyKeepScreen();
    this.startBreath();
    this.scheduleHide();
    this.maybeGuide();
    const local: ArchiveBook | null = appStore.localArchive;
    if (local !== null) {
      this.archive = local;
      this.localId = appStore.localArchiveId;
      this.title = local.title;
      this.total = local.pages.length;
      this.page = Math.min(Math.max(1, appStore.localArchivePage), Math.max(1, this.total));
      if (this.mode === 'spread' && this.page > 1 && this.page % 2 === 1) {
        this.page = this.page - 1;
      }
      this.load(this.page);
      this.load(this.page + 1);
      this.source.reset(this.total);
      this.thumbSource.reset(this.total);
      AppStorage.setOrCreate('comicCurPage', this.page);
      this.scrollTarget = this.page;
      return;
    }
    const book = appStore.selected;
    this.title = appStore.readerTitle.length > 0 ? appStore.readerTitle : t('漫画');
    this.total = book !== null && book.pages > 0 ? book.pages : 0;
    this.page = this.total > 0 ? Math.min(Math.max(1, appStore.readerChapter), this.total) : 1;
    if (this.mode === 'spread' && this.page > 1 && this.page % 2 === 1) {
      this.page = this.page - 1;
    }
    this.incognito = appStore.readerIncognito;
    this.bookId = appStore.readerBookId.length > 0 ? appStore.readerBookId : (book !== null ? book.id : '');
    this.load(this.page);
    this.load(this.page + 1);
    this.source.reset(this.total);
    this.thumbSource.reset(this.total);
    this.scrollTarget = this.page;
    readingTracker.start(this.bookId, this.page, this.incognito);
  }

  private applyKeepScreen(): void {
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    window.getLastWindow(context).then((win: window.Window) => {
      win.setWindowKeepScreenOn(Prefs.bool(PrefKeys.keepScreen, true));
      WindowFx.enterImmersive(win);
      this.safeTop = WindowFx.safeTop(win);
      this.safeBottom = WindowFx.safeBottom(win);
    }).catch(() => {
    });
  }

  private releaseImmersive(): void {
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    window.getLastWindow(context).then((win: window.Window) => {
      WindowFx.exitImmersive(win);
    }).catch(() => {
    });
  }

  private startBreath(): void {
    this.getUIContext().animateTo({
      duration: 1000,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.breath = 0.82;
    });
  }

  private scheduleHide(): void {
    this.clearBarTimer();
    this.barTimer = setTimeout(() => {
      this.barTimer = -1;
      if (!this.bar || this.panel || this.thumbs || this.guideOpen) {
        return;
      }
      this.bar = false;
    }, 3200);
  }

  private clearBarTimer(): void {
    if (this.barTimer >= 0) {
      clearTimeout(this.barTimer);
      this.barTimer = -1;
    }
  }

  private maybeGuide(): void {
    if (Prefs.bool(PrefKeys.comicGuide, false)) {
      return;
    }
    setTimeout(() => {
      if (this.guideOpen) {
        return;
      }
      this.bar = true;
      this.guideStep = 0;
      this.guideOpen = true;
    }, 900);
  }

  onGuide(): void {
    if (this.guideOpen) {
      this.bar = true;
      this.clearBarTimer();
      this.guideNeedKey = '';
      return;
    }
    this.guideNeedKey = '';
    this.panel = false;
    this.thumbs = false;
    Prefs.putBool(PrefKeys.comicGuide, true);
    this.scheduleHide();
  }

  private guideNeed(need: string): void {
    if (this.guideNeedKey === need) {
      return;
    }
    this.guideNeedKey = need;
    this.panel = need === 'panel';
    this.thumbs = need === 'thumbs';
    if (this.thumbs) {
      this.focusThumbs();
    }
  }

  private openGuide(): void {
    this.panel = false;
    this.thumbs = false;
    this.guideNeedKey = '';
    this.guideStep = 0;
    this.guideOpen = true;
  }

  private num(v: Length): number {
    return typeof v === 'number' ? v as number : parseFloat(`${v}`);
  }

  private boxOf(area: Area): string {
    const pos: Position = area.globalPosition;
    const x: number = pos.x === undefined ? 0 : this.num(pos.x);
    const y: number = pos.y === undefined ? 0 : this.num(pos.y);
    const w: number = this.num(area.width);
    const h: number = this.num(area.height);
    return `${Math.round(x)},${Math.round(y)},${Math.round(w)},${Math.round(h)}`;
  }

  private toggleBar(): void {
    this.bar = !this.bar;
    if (this.bar) {
      this.scheduleHide();
    } else {
      this.clearBarTimer();
    }
  }

  private onBack(): boolean {
    if (this.guideOpen) {
      this.guideOpen = false;
      return true;
    }
    if (this.panel) {
      this.panel = false;
      return true;
    }
    if (this.thumbs) {
      this.thumbs = false;
      return true;
    }
    if (this.bar) {
      this.bar = false;
      this.clearBarTimer();
      return true;
    }
    return false;
  }

  aboutToDisappear(): void {
    appStore.backHook = null;
    readingTracker.stop();
    this.disarmGuard();
    this.clearBarTimer();
    this.releaseImmersive();
    appStore.readerIncognito = false;
    if (this.archive !== null) {
      appStore.localArchivePage = this.page;
      this.saveLocal();
    } else {
      this.flushProgress();
    }
    appStore.localArchive = null;
    appStore.localArchiveId = '';
    this.cache.forEach((item: image.PixelMap) => {
      item.release();
    });
    this.cache.clear();
    this.pixmap = undefined;
  }

  private async load(n: number): Promise<void> {
    const archive: ArchiveBook | null = this.archive;
    if (archive === null && this.bookId.length === 0) {
      this.failed = t('缺少书籍标识，无法定位页图');
      return;
    }
    if (n < 1) {
      return;
    }
    if (this.total > 0 && n > this.total) {
      return;
    }
    const hit: image.PixelMap | undefined = this.cache.get(n);
    if (hit !== undefined) {
      if (n === this.page) {
        this.pixmap = hit;
        this.failed = '';
      } else if (this.mode === 'spread' && this.page > 1 && n === this.page + 1) {
        this.pixmap2 = hit;
        this.failed2 = '';
      }
      return;
    }
    if (n === this.page) {
      this.loading = true;
      this.armGuard(n);
    }
    try {
      let bytes: ArrayBuffer;
      if (archive !== null) {
        bytes = await comicArchive.readPage(archive, n);
      } else {
        const local: ArrayBuffer | null = offlinePage(this.bookId, n, 'jpeg');
        bytes = local !== null ? local : await appStore.api.page(this.bookId, n, 'jpeg', this.qualityWidth());
      }
      const pixel: image.PixelMap = await this.prepImage(bytes);
      this.cache.set(n, pixel);
      this.evict(n);
      if (n === this.page) {
        this.pixmap = pixel;
        this.failed = '';
      } else if (this.mode === 'spread' && this.page > 1 && n === this.page + 1) {
        this.pixmap2 = pixel;
        this.failed2 = '';
      }
    } catch (error) {
      const msg: string = this.reasonOf(error as Error);
      if (n === this.page) {
        this.pixmap = undefined;
        this.failed = msg;
      } else if (this.mode === 'spread' && this.page > 1 && n === this.page + 1) {
        this.pixmap2 = undefined;
        this.failed2 = msg;
      }
    }
    if (n === this.page) {
      this.loading = false;
      this.disarmGuard();
    }
  }

  private armGuard(n: number): void {
    this.disarmGuard();
    this.guard = setTimeout(() => {
      this.guard = -1;
      if (this.page === n && this.loading) {
        this.loading = false;
        this.pixmap = undefined;
        this.failed = t('页图加载超时');
      }
    }, 15000);
  }

  private disarmGuard(): void {
    if (this.guard >= 0) {
      clearTimeout(this.guard);
      this.guard = -1;
    }
  }

  private evict(keep: number): void {
    if (this.cache.size <= 3) {
      return;
    }
    const keys: number[] = [];
    this.cache.forEach((item: image.PixelMap, key: number) => {
      keys.push(key);
    });
    for (let index = 0; index < keys.length; index++) {
      const key: number = keys[index];
      if (key === keep || Math.abs(key - this.page) <= 1) {
        continue;
      }
      const pixel: image.PixelMap | undefined = this.cache.get(key);
      if (pixel !== undefined) {
        pixel.release();
        this.cache.delete(key);
      }
    }
  }

  private percent(): number {
    const at: number = this.displayPage();
    return this.total > 0 ? Math.round(at / this.total * 100) : 0;
  }

  private displayPage(): number {
    return this.sliderPage > 0 ? this.sliderPage : this.page;
  }

  private displayLabel(): string {
    const at: number = this.displayPage();
    if (this.mode === 'spread' && at > 1 && at + 1 <= this.total) {
      return `${at}-${at + 1}`;
    }
    return `${at}`;
  }

  private seek(value: number, mode: SliderChangeMode): void {
    const target: number = Math.round(value);
    if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
      this.sliderPage = target;
      return;
    }
    this.sliderPage = 0;
    this.jumpTo(target);
  }

  private jumpTo(target: number): void {
    if (this.total <= 0) {
      return;
    }
    const n: number = Math.min(this.total, Math.max(1, target));
    if (this.mode === 'scroll') {
      this.page = n;
      this.scrollTarget = n;
      this.scrollToPage();
      return;
    }
    let next: number = n;
    if (this.mode === 'spread' && next > 1 && next % 2 === 1) {
      next = next - 1;
    }
    this.page = next;
    this.pixmap2 = undefined;
    this.pixmap = this.cache.get(next);
    this.failed = '';
    this.failed2 = '';
    this.load(next);
    this.load(next + 1);
    if (this.bar) {
      this.scheduleHide();
    }
  }

  private turn(delta: number): void {
    let next: number = this.page + (this.mode === 'spread' ? delta * 2 : delta);
    if (this.mode === 'spread') {
      if (next <= 1) {
        next = 1;
      } else if (next % 2 === 1) {
        next = next - 1;
      }
    }
    if (next < 1 || (this.total > 0 && next > this.total)) {
      return;
    }
    this.page = next;
    this.pixmap2 = undefined;
    const hit: image.PixelMap | undefined = this.cache.get(next);
    if (hit !== undefined) {
      this.pixmap = hit;
    } else if (this.mode === 'spread') {
      this.pixmap = undefined;
    }
    this.failed = '';
    this.failed2 = '';
    this.load(next);
    this.load(next + 1);
    if (this.bar) {
      this.scheduleHide();
    }
  }

  @Builder
  topBar() {
    Row({ space: 8 }) {
      Row() {
        GlyphIcon({ glyphName: 'back', glyphSize: 17, glyphColor: C.tx2 })
      }
      .width(31)
      .height(31)
      .justifyContent(FlexAlign.Center)
      .borderRadius(9)
      .border({ width: 1, color: C.hair })
      .id('comic_top_back')
      .onClick(() => {
        this.nav.pop();
      })

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(13)
          .fontFamily(FT.disp)
          .letterSpacing(0.6)
          .fontColor(C.tx)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.total > 0 ? tf('第 {0} / {1} 页{2}', [this.pageLabel(), `${this.total}`, this.incognito ? t(' · 隐身') : '']) : (this.incognito ? t('隐身阅读') : t('阅读中')))
          .fontSize(9.5)
          .fontColor(this.incognito ? C.acc2 : C.tx3)
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .id('comic_top_title')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: this.safeTop + 10, bottom: 10 })
    .linearGradient({ angle: 180, colors: [['#F20E100F', 0.0], ['#D90A0B0B', 1.0]] })
    .border({ width: { bottom: 1 }, color: C.line })
    .id('comic_guide_top')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.topRect = this.boxOf(newArea);
    })
  }

  @Builder
  stage() {
    Stack() {
      if (this.mode === 'spread') {
        Row() {
          if (this.pixmap !== undefined) {
            Image(this.pixmap)
              .objectFit(ImageFit.Contain)
              .layoutWeight(1)
              .height('100%')
          } else if (this.failed.length > 0) {
            Column() {
              PageFailBox({
                pageNo: this.page,
                reason: this.failed,
                compact: true,
                onRetry: () => {
                  this.load(this.page);
                }
              })
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.Center)
          } else {
            Column() {
              LoadingProgress().width(20).height(20).color(C.acc)
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.Center)
          }
          if (this.page + 1 <= this.total) {
            if (this.pixmap2 !== undefined) {
              Image(this.pixmap2)
                .objectFit(ImageFit.Contain)
                .layoutWeight(1)
                .height('100%')
            } else if (this.failed2.length > 0) {
              Column() {
                PageFailBox({
                  pageNo: this.page + 1,
                  reason: this.failed2,
                  compact: true,
                  onRetry: () => {
                    this.load(this.page + 1);
                  }
                })
              }
              .layoutWeight(1)
              .height('100%')
              .justifyContent(FlexAlign.Center)
            } else {
              Column() {
                LoadingProgress().width(20).height(20).color(C.acc)
              }
              .layoutWeight(1)
              .height('100%')
              .justifyContent(FlexAlign.Center)
            }
          }
        }
        .width('100%')
        .height('100%')
      } else if (this.pixmap !== undefined) {
        ComicZoomLayer({
          pixmap: this.pixmap,
          pageKey: this.page,
          onZoom: (z: number) => {
            this.zoom = z;
          },
          onSwipe: (delta: number) => {
            if (this.swipeTurn && !this.guideOpen) {
              this.turn(delta);
            }
          },
          onTapZone: (delta: number) => {
            this.zoneTapPaged(delta);
          }
        })

        if (this.loading) {
          this.turningVeil()
        }
      } else if (this.failed.length > 0) {
        Column() {
          PageFailBox({
            pageNo: this.page,
            reason: this.failed,
            compact: false,
            onRetry: () => {
              this.load(this.page);
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        this.pageSkeleton()
      }

      if (this.mode === 'spread' || this.pixmap === undefined) {
        this.zoneRow()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0a0b0b')
  }

  @Builder
  zoneRow() {
    Row() {
      Column()
        .layoutWeight(1)
        .height('100%')
        .onClick(() => {
          this.zoneTapPaged(-1);
        })
      Column()
        .layoutWeight(1.4)
        .height('100%')
        .onClick(() => {
          this.zoneTapPaged(0);
        })
      Column()
        .layoutWeight(1)
        .height('100%')
        .onClick(() => {
          this.zoneTapPaged(1);
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  pageSkeleton() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(C.bg1)
        .opacity(this.breath)

      Column({ space: 12 }) {
        LoadingProgress().width(26).height(26).color(C.acc)
        Text(this.total > 0 ? tf('第 {0} / {1} 页', [`${this.page}`, `${this.total}`]) : t('正在载入页面'))
          .fontSize(11)
          .fontFamily(FT.mono)
          .fontColor(C.tx3)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  turningVeil() {
    Column() {
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(2)
          .backgroundColor('#1f2624')
        Row()
          .width(`${Math.max(4, this.percent())}%`)
          .height(2)
          .backgroundColor(C.acc)
      }
      .width('100%')
      .height(2)

      Blank()

      Row({ space: 8 }) {
        LoadingProgress().width(13).height(13).color(C.acc)
        Text(this.total > 0 ? tf('{0} / {1}', [`${this.page}`, `${this.total}`]) : `${this.page}`)
          .fontSize(10)
          .fontFamily(FT.mono)
          .fontColor(C.tx2)
      }
      .padding({ left: 10, right: 12, top: 5, bottom: 5 })
      .backgroundColor(C.glassDeep)
      .borderRadius(99)
      .border({ width: 1, color: C.line })
      .margin({ bottom: this.safeBottom + 24 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  private pickQuality(index: number): void {
    if (this.qualityIndex === index) {
      return;
    }
    this.qualityIndex = index;
    Prefs.putInt(PrefKeys.cmQuality, index);
    this.reload();
  }

  private qualityWidth(): number {
    const q: number = Prefs.int(PrefKeys.cmQuality, 2);
    return q === 0 ? 720 : (q === 1 ? 1080 : 0);
  }

  private pageLabel(): string {
    if (this.mode === 'spread' && this.page > 1 && this.page + 1 <= this.total) {
      return `${this.page}-${this.page + 1}`;
    }
    return `${this.page}`;
  }

  private async prepImage(bytes: ArrayBuffer): Promise<image.PixelMap> {
    const source: image.ImageSource = image.createImageSource(bytes);
    try {
      const options: image.DecodingOptions = { editable: true };
      const pixel: image.PixelMap | undefined = await source.createPixelMap(options) as image.PixelMap | undefined;
      if (pixel === undefined) {
        throw new Error(t('页图解码失败'));
      }
      await ImageOps.tune(pixel, this.crop, this.enhance);
      return pixel;
    } finally {
      source.release();
    }
  }

  private reasonOf(error: Error): string {
    const raw: string = error.message ?? '';
    if (raw.length === 0) {
      return t('页图加载失败');
    }
    return raw.length > 40 ? raw.substring(0, 40) + '…' : raw;
  }

  private reload(): void {
    this.cache.forEach((item: image.PixelMap) => {
      item.release();
    });
    this.cache.clear();
    this.pixmap = undefined;
    this.pixmap2 = undefined;
    this.failed = '';
    this.failed2 = '';
    this.stripVersion = this.stripVersion + 1;
    this.load(this.page);
    if (this.mode === 'spread') {
      this.load(this.page + 1);
    }
  }

  private resetZoom(): void {
    this.zoom = 1;
    this.panOffX = 0;
    this.panBaseX = 0;
    this.pinchBase = 1;
  }

  private clampPan(value: number): number {
    if (this.zoom <= 1.01 || this.stageW <= 0) {
      return 0;
    }
    const limit: number = this.stageW * (this.zoom - 1) / 2;
    return Math.max(-limit, Math.min(limit, value));
  }

  private panGainX(): number {
    return Math.min(3.2, 1 + (this.zoom - 1) * 0.9);
  }

  private onRootTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.tMove = 0;
      if (event.touches.length > 0) {
        this.tDownX = event.touches[0].windowX;
        this.tDownY = event.touches[0].windowY;
      }
      return;
    }
    if (event.type === TouchType.Move && event.touches.length > 0) {
      const dx: number = Math.abs(event.touches[0].windowX - this.tDownX);
      const dy: number = Math.abs(event.touches[0].windowY - this.tDownY);
      this.tMove = Math.max(this.tMove, Math.max(dx, dy));
    }
  }

  private zoneTapPaged(delta: number): void {
    if (this.guideOpen || this.zoom > 1 || this.tMove > 10) {
      return;
    }
    if (delta === 0) {
      this.toggleBar();
      return;
    }
    this.turn(delta);
  }

  private switchMode(): void {
    this.resetZoom();
    this.pixmap2 = undefined;
    this.failed = '';
    this.failed2 = '';
    if (this.mode === 'spread' && this.page > 1 && this.page % 2 === 1) {
      this.page = this.page - 1;
    }
    this.load(this.page);
    if (this.mode === 'spread') {
      this.load(this.page + 1);
    }
    this.scrollTarget = this.page;
    this.scrollToPage();
  }

  private scrollToPage(): void {
    if (this.mode !== 'scroll') {
      return;
    }
    const target: number = Math.max(0, this.scrollTarget - 1);
    setTimeout(() => {
      try {
        this.scroller.scrollToIndex(target);
      } catch (error) {
      }
    }, 400);
  }

  private zoneTap(x: number, w: number): void {
    if (this.tMove > 10 || this.zoom > 1.01) {
      return;
    }
    if (w <= 0) {
      this.toggleBar();
      return;
    }
    if (x < w * 0.28) {
      this.scrollTurn(-1);
      return;
    }
    if (x > w * 0.72) {
      this.scrollTurn(1);
      return;
    }
    this.toggleBar();
  }

  private scrollTurn(delta: number): void {
    const next: number = this.page + delta;
    if (next < 1 || (this.total > 0 && next > this.total)) {
      return;
    }
    this.page = next;
    this.scrollTarget = next;
    this.scrollToPage();
  }

  @Builder
  scrollStage() {
    List({ scroller: this.scroller }) {
      LazyForEach(this.source, (item: number) => {
        ListItem() {
          ComicStrip({
            bookId: this.bookId,
            pageNo: item,
            useArchive: this.archive !== null,
            crop: this.crop,
            enhance: this.enhance,
            pageWidth: this.qualityWidth(),
            version: this.stripVersion
          })
        }
      }, (item: number) => `strip-${item}`)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0a0b0b')
    .cachedCount(2)
    .scale({ x: this.zoom, y: this.zoom })
    .translate({ x: this.panOffX })
    .parallelGesture(
      PinchGesture({ fingers: 2 })
        .onActionStart(() => {
          this.pinchBase = this.zoom;
        })
        .onActionUpdate((event: GestureEvent) => {
          this.zoom = Math.min(3, Math.max(1, this.pinchBase * event.scale));
          this.panOffX = this.clampPan(this.panOffX);
        })
        .onActionEnd(() => {
          if (this.zoom < 1.05) {
            this.resetZoom();
          } else {
            this.pinchBase = this.zoom;
            this.panOffX = this.clampPan(this.panOffX);
          }
        })
    )
    .parallelGesture(
      PanGesture({ fingers: 1, distance: 1 })
        .onActionStart(() => {
          this.panBaseX = this.panOffX;
          this.panLastX = 0;
        })
        .onActionUpdate((event: GestureEvent) => {
          const dx: number = event.offsetX - this.panLastX;
          this.panLastX = event.offsetX;
          if (this.zoom <= 1.01) {
            return;
          }
          this.panOffX = this.clampPan(this.panOffX + dx * this.panGainX());
        })
        .onActionEnd(() => {
          this.panBaseX = this.clampPan(this.panOffX);
          this.panOffX = this.panBaseX;
        })
    )
    .onAppear(() => {
      this.scrollToPage();
    })
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.stageW = this.num(newArea.width);
    })
    .onClick((event: ClickEvent) => {
      this.zoneTap(event.x, this.stageW);
    })
    .onScrollIndex((start: number) => {
      const n: number = start + 1;
      if (n !== this.page) {
        this.page = n;
      }
    })
  }

  @Builder
  layoutPanel() {
    Column({ space: 9 }) {
    Row({ space: 8 }) {
      Text(t('单页'))
        .fontSize(11)
        .fontColor(this.mode === 'paged' ? C.acc2 : C.tx3)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(this.mode === 'paged' ? C.accBg : C.bg2)
        .borderRadius(99)
        .border({ width: 1, color: this.mode === 'paged' ? C.accLine : C.line })
        .onClick(() => {
          this.mode = 'paged';
          this.switchMode();
        })
      Text(t('双页'))
        .fontSize(11)
        .fontColor(this.mode === 'spread' ? C.acc2 : C.tx3)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(this.mode === 'spread' ? C.accBg : C.bg2)
        .borderRadius(99)
        .border({ width: 1, color: this.mode === 'spread' ? C.accLine : C.line })
        .onClick(() => {
          this.mode = 'spread';
          this.switchMode();
        })
      Text(t('连续滚动'))
        .fontSize(11)
        .fontColor(this.mode === 'scroll' ? C.acc2 : C.tx3)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(this.mode === 'scroll' ? C.accBg : C.bg2)
        .borderRadius(99)
        .border({ width: 1, color: this.mode === 'scroll' ? C.accLine : C.line })
        .onClick(() => {
          this.mode = 'scroll';
          this.switchMode();
        })
      Blank()
      Text(`${this.zoom.toFixed(1)}x`)
        .fontSize(10)
        .fontFamily(FT.mono)
        .fontColor(C.tx4)
    }
    .id('comic_panel_mode')
    .width('100%')

    Row({ space: 10 }) {
      Row({ space: 4 }) {
        Text(t('裁白边'))
          .fontSize(11)
          .fontColor(C.tx3)
          .width(46)
        Toggle({ type: ToggleType.Switch, isOn: this.crop })
          .onChange((on: boolean) => {
            this.crop = on;
            this.reload();
          })
      }
      .id('comic_panel_crop')

      Row({ space: 4 }) {
        Text(t('校色'))
          .fontSize(11)
          .fontColor(C.tx3)
          .width(34)
        Toggle({ type: ToggleType.Switch, isOn: this.enhance })
          .onChange((on: boolean) => {
            this.enhance = on;
            this.reload();
          })
      }
      .id('comic_panel_enhance')
      Blank()
    }
    .width('100%')

    Row({ space: 8 }) {
      Text(t('画质'))
        .fontSize(11)
        .fontColor(C.tx3)
        .width(34)
      Text(t('省流'))
        .fontSize(11)
        .fontColor(this.qualityIndex === 0 ? C.acc2 : C.tx3)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.qualityIndex === 0 ? C.accBg : C.bg2)
        .borderRadius(99)
        .border({ width: 1, color: this.qualityIndex === 0 ? C.accLine : C.line })
        .onClick(() => {
          this.pickQuality(0);
        })
      Text(t('标准'))
        .fontSize(11)
        .fontColor(this.qualityIndex === 1 ? C.acc2 : C.tx3)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.qualityIndex === 1 ? C.accBg : C.bg2)
        .borderRadius(99)
        .border({ width: 1, color: this.qualityIndex === 1 ? C.accLine : C.line })
        .onClick(() => {
          this.pickQuality(1);
        })
      Text(t('高清'))
        .fontSize(11)
        .fontColor(this.qualityIndex === 2 ? C.acc2 : C.tx3)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.qualityIndex === 2 ? C.accBg : C.bg2)
        .borderRadius(99)
        .border({ width: 1, color: this.qualityIndex === 2 ? C.accLine : C.line })
        .onClick(() => {
          this.pickQuality(2);
        })
      Blank()
    }
    .id('comic_panel_quality')
    .width('100%')

    Row({ space: 8 }) {
      GlyphIcon({ glyphName: 'info', glyphSize: 13, glyphColor: C.tx3 })
      Text(t('操作指引'))
        .fontSize(11)
        .fontColor(C.tx2)
      Blank()
      Text(t('逐步演示'))
        .fontSize(10)
        .fontColor(C.tx4)
    }
    .width('100%')
    .id('comic_panel_guide')
    .onClick(() => {
      this.openGuide();
    })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(C.glassDeep)
    .border({ width: { top: 1 }, color: C.line })
  }

  @Builder
  thumbsStrip() {
    List({ space: 7, scroller: this.thumbScroller }) {
      LazyForEach(this.thumbSource, (item: number) => {
        ListItem() {
          ComicThumb({
            bookId: this.bookId,
            pageNo: item,
            useArchive: this.archive !== null
          })
        }
        .padding({ top: 3, bottom: 3 })
        .onClick(() => {
          this.pickPage(item);
        })
      }, (item: number) => `t-${item}`)
    }
    .listDirection(Axis.Horizontal)
    .cachedCount(3)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height(88)
    .padding({ left: 10, right: 10 })
    .backgroundColor(C.glassDeep)
    .border({ width: { top: 1 }, color: C.line })
    .onScroll(() => {
      this.holdThumbs();
    })
    .onScrollStop(() => {
      this.releaseThumbs();
    })
    .id('comic_thumbs_strip')
  }

  @Builder
  bottomBar() {
    Column({ space: 11 }) {
      Row({ space: 10 }) {
        Text(this.total > 0 ? `${this.displayLabel()} / ${this.total}` : `${this.page}`)
          .fontSize(10)
          .fontFamily(FT.mono)
          .fontColor(this.sliderPage > 0 ? C.acc2 : C.tx3)
          .width(52)
          .id('comic_prog_pos')

        Slider({
          value: this.displayPage(),
          min: 1,
          max: Math.max(1, this.total),
          step: 1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .height(22)
          .trackThickness(3)
          .blockSize({ width: 12, height: 12 })
          .selectedColor(C.acc)
          .trackColor(C.line2)
          .blockColor(C.acc)
          .enabled(this.total > 1)
          .id('comic_prog_slider')
          .onChange((value: number, mode: SliderChangeMode) => {
            this.seek(value, mode);
          })

        Text(`${this.percent()}%`)
          .fontSize(10)
          .fontFamily(FT.mono)
          .fontColor(this.sliderPage > 0 ? C.acc2 : C.tx3)
          .width(44)
          .textAlign(TextAlign.End)
          .id('comic_prog_pct')

        Row() {
          GlyphIcon({ glyphName: 'back', glyphSize: 15, glyphColor: C.tx2 })
        }
        .width(31)
        .height(31)
        .justifyContent(FlexAlign.Center)
        .borderRadius(8)
        .border({ width: 1, color: C.hair })
        .id('comic_prog_prev')
        .onClick(() => {
          this.turn(-1);
        })

        Row() {
          GlyphIcon({ glyphName: 'next', glyphSize: 15, glyphColor: C.tx2 })
        }
        .width(31)
        .height(31)
        .justifyContent(FlexAlign.Center)
        .borderRadius(8)
        .border({ width: 1, color: C.hair })
        .id('comic_prog_next')
        .onClick(() => {
          this.turn(1);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .id('comic_guide_progress')
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.progressRect = this.boxOf(newArea);
      })

      Row() {
        ForEach(tools(), (item: ComicTool) => {
          Column({ space: 3 }) {
            GlyphIcon({
              glyphName: item.icon,
              glyphSize: 19,
              glyphColor: item.icon === 'thumbs' && this.thumbs ? C.acc2 : C.tx3
            })
            Text(item.label)
              .fontSize(9)
              .fontColor(item.icon === 'thumbs' && this.thumbs ? C.acc2 : C.tx3)
              .maxLines(1)
          }
          .layoutWeight(1)
          .id(`comic_tool_${item.icon}`)
          .onClick(() => {
            if (item.icon === 'thumbs') {
              this.thumbs = !this.thumbs;
              if (this.thumbs) {
                this.focusThumbs();
              }
            } else if (item.icon === 'settings') {
              this.panel = !this.panel;
            } else if (item.icon === 'bookmark') {
              this.bookmarked = !this.bookmarked;
            }
          })
        }, (item: ComicTool) => item.label)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: this.safeBottom + 12 })
    .linearGradient({ angle: 0, colors: [['#D90A0B0B', 0.0], ['#F20E100F', 1.0]] })
    .border({ width: { top: 1 }, color: C.line })
    .id('comic_guide_bottom')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.bottomRect = this.boxOf(newArea);
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.mode === 'scroll') {
        this.scrollStage()
      } else {
        this.stage()
      }

      if (this.bar) {
        Column() {
          this.topBar()
          Blank()
          if (this.panel) {
            this.layoutPanel()
          }
          if (this.thumbs) {
            this.thumbsStrip()
          }
          this.bottomBar()
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
        .transition(TransitionEffect.OPACITY.animation({ duration: 160 }))
      }

      if (this.guideOpen) {
        ReaderGuide({
          visible: $guideOpen,
          index: $guideStep,
          safeTop: this.safeTop,
          safeBottom: this.safeBottom,
          onNeed: (need: string) => {
            this.guideNeed(need);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0a0b0b')
    .id('comic_guide_root')
    .onTouch((event: TouchEvent) => {
      this.onRootTouch(event);
    })
  }
}

@Component
struct PageFailBox {
  @Prop pageNo: number = 0;
  @Prop reason: string = '';
  @Prop compact: boolean = false;
  onRetry: () => void = () => {
  };

  build() {
    Column({ space: this.compact ? 5 : 9 }) {
      GlyphIcon({ glyphName: 'warn', glyphSize: this.compact ? 16 : 21, glyphColor: C.bad })
      Text(tf('第 {0} 页加载失败', [`${this.pageNo}`]))
        .fontSize(this.compact ? 10.5 : 12.5)
        .fontColor(C.tx2)
        .textAlign(TextAlign.Center)
      if (this.reason.length > 0) {
        Text(this.reason)
          .fontSize(this.compact ? 8.5 : 9.5)
          .fontColor(C.tx4)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .padding({ left: 10, right: 10 })
      }
      Row({ space: 5 }) {
        GlyphIcon({ glyphName: 'sync', glyphSize: this.compact ? 10 : 12, glyphColor: C.acc })
        Text(t('重试'))
          .fontSize(this.compact ? 10 : 11)
          .fontColor(C.acc)
      }
      .padding({ left: 11, right: 13, top: 4, bottom: 4 })
      .borderRadius(99)
      .border({ width: 1, color: C.accLine })
      .onClick(() => {
        this.onRetry();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}

@Component
struct ComicZoomLayer {
  @Prop pixmap: image.PixelMap | undefined = undefined;
  @Prop @Watch('onPage') pageKey: number = 0;
  onZoom: (z: number) => void = () => {
  };
  onSwipe: (delta: number) => void = () => {
  };
  onTapZone: (delta: number) => void = () => {
  };
  @State zoom: number = 1;
  @State offX: number = 0;
  @State offY: number = 0;
  @State cx: string | number = '50%';
  @State cy: string | number = '50%';
  private base: number = 1;
  private lastX: number = 0;
  private lastY: number = 0;
  private moved: number = 0;
  private tMove: number = 0;
  private tX: number = 0;
  private tY: number = 0;
  private w: number = 0;
  private h: number = 0;

  onPage(): void {
    this.restore();
  }

  private restore(): void {
    this.zoom = 1;
    this.offX = 0;
    this.offY = 0;
    this.cx = '50%';
    this.cy = '50%';
    this.base = 1;
    this.lastX = 0;
    this.lastY = 0;
    this.moved = 0;
    this.onZoom(1);
  }

  private clampX(v: number): number {
    const l: number = this.w * (this.zoom - 1) / 2;
    return Math.max(-l, Math.min(l, v));
  }

  private clampY(v: number): number {
    const l: number = this.h * (this.zoom - 1) / 2;
    return Math.max(-l, Math.min(l, v));
  }

  private zoomHere(event: GestureEvent): void {
    if (this.zoom > 1) {
      this.restore();
      return;
    }
    const x: number = event.fingerList.length > 0 ? event.fingerList[0].localX : this.w / 2;
    const y: number = event.fingerList.length > 0 ? event.fingerList[0].localY : this.h / 2;
    this.cx = x;
    this.cy = y;
    this.zoom = 1.5;
    this.base = 1.5;
    this.onZoom(1.5);
  }

  private gainX(): number {
    return Math.min(3.4, 1 + (this.zoom - 1) * 1.05);
  }

  private gainY(): number {
    return Math.min(2.2, 1 + (this.zoom - 1) * 0.45);
  }

  private dragMove(event: GestureEvent): void {
    const dx: number = event.offsetX - this.lastX;
    const dy: number = event.offsetY - this.lastY;
    this.lastX = event.offsetX;
    this.lastY = event.offsetY;
    this.moved = Math.max(this.moved, Math.abs(event.offsetX) + Math.abs(event.offsetY));
    if (this.zoom <= 1) {
      return;
    }
    this.offX = this.clampX(this.offX + dx * this.gainX());
    this.offY = this.clampY(this.offY + dy * this.gainY());
  }

  private dragEnd(event: GestureEvent): void {
    const travel: number = this.moved;
    this.moved = 0;
    if (this.zoom > 1) {
      this.onZoom(this.zoom);
      return;
    }
    if (travel < 14 || Math.abs(event.offsetX) < 88) {
      return;
    }
    if (Math.abs(event.offsetX) < Math.abs(event.offsetY) * 1.6) {
      return;
    }
    this.onSwipe(event.offsetX < 0 ? 1 : -1);
  }

  private touchTrace(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.tMove = 0;
      if (event.touches.length > 0) {
        this.tX = event.touches[0].windowX;
        this.tY = event.touches[0].windowY;
      }
      return;
    }
    if (event.type === TouchType.Move && event.touches.length > 0) {
      const dx: number = Math.abs(event.touches[0].windowX - this.tX);
      const dy: number = Math.abs(event.touches[0].windowY - this.tY);
      this.tMove = Math.max(this.tMove, Math.max(dx, dy));
    }
  }

  build() {
    Stack() {
      Stack() {
        if (this.pixmap !== undefined) {
          Image(this.pixmap)
            .objectFit(ImageFit.Contain)
            .width('100%')
            .height('100%')
            .scale({ x: this.zoom, y: this.zoom, centerX: this.cx, centerY: this.cy })
        }
      }
      .width('100%')
      .height('100%')
      .translate({ x: this.offX, y: this.offY })
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.w = typeof newArea.width === 'number' ? newArea.width as number : parseFloat(`${newArea.width}`);
      this.h = typeof newArea.height === 'number' ? newArea.height as number : parseFloat(`${newArea.height}`);
    })
    .onTouch((event: TouchEvent) => {
      this.touchTrace(event);
    })
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart(() => {
            this.base = this.zoom;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.zoom = Math.min(4, Math.max(1, this.base * event.scale));
            this.offX = this.clampX(this.offX);
            this.offY = this.clampY(this.offY);
          })
          .onActionEnd(() => {
            if (this.zoom < 1.05) {
              this.restore();
            } else {
              this.base = this.zoom;
              this.onZoom(this.zoom);
            }
          }),
        PanGesture({ fingers: 1, distance: 1 })
          .onActionStart(() => {
            this.lastX = 0;
            this.lastY = 0;
            this.moved = 0;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.dragMove(event);
          })
          .onActionEnd((event: GestureEvent) => {
            this.dragEnd(event);
          }),
        LongPressGesture({ repeat: false, duration: 380 })
          .onAction((event: GestureEvent) => {
            if (this.moved > 14) {
              return;
            }
            this.zoomHere(event);
          }),
        TapGesture({ count: 1 })
          .onAction((event: GestureEvent) => {
            if (this.zoom > 1 || this.tMove > 10) {
              return;
            }
            const x: number = event.fingerList.length > 0 ? event.fingerList[0].localX : this.w / 2;
            if (x < this.w * 0.294) {
              this.onTapZone(-1);
            } else if (x > this.w * 0.706) {
              this.onTapZone(1);
            } else {
              this.onTapZone(0);
            }
          })
      )
    )
  }
}

@Component
struct ComicThumb {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('comicThumbBusy') @Watch('onBusy') busy: boolean = false;
  @StorageLink('comicCurPage') curPage: number = 1;
  @Prop bookId: string = '';
  @Prop pageNo: number = 0;
  @Prop useArchive: boolean = false;
  @State pixmap: image.PixelMap | undefined = undefined;
  @State err: boolean = false;

  aboutToAppear(): void {
    if (!this.busy) {
      this.load();
    }
  }

  aboutToDisappear(): void {
    if (this.pixmap !== undefined) {
      this.pixmap.release();
      this.pixmap = undefined;
    }
  }

  onBusy(): void {
    if (!this.busy && this.pixmap === undefined && !this.err) {
      this.load();
    }
  }

  private async load(): Promise<void> {
    if (this.pageNo < 1) {
      return;
    }
    try {
      let bytes: ArrayBuffer;
      if (this.useArchive) {
        const book: ArchiveBook | null = appStore.localArchive;
        if (book === null) {
          return;
        }
        bytes = await comicArchive.readPage(book, this.pageNo);
      } else {
        try {
          bytes = await appStore.api.page(this.bookId, this.pageNo, 'jpeg', 300);
        } catch (error) {
          bytes = await appStore.api.pageThumb(this.bookId, this.pageNo);
        }
      }
      const source: image.ImageSource = image.createImageSource(bytes);
      try {
        const pixel: image.PixelMap | undefined =
          await source.createPixelMap() as image.PixelMap | undefined;
        if (pixel !== undefined) {
          this.pixmap = pixel;
          this.err = false;
        } else {
          this.err = true;
        }
      } finally {
        source.release();
      }
    } catch (error) {
      hilog.warn(0x0000, 'LantaiThumb', 'page %{public}d failed: %{public}s', this.pageNo,
        (error as Error).message);
      this.pixmap = undefined;
      this.err = true;
    }
  }

  build() {
    Stack() {
      if (this.pixmap !== undefined) {
        Image(this.pixmap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else if (this.err) {
        Column({ space: 3 }) {
          GlyphIcon({ glyphName: 'warn', glyphSize: 15, glyphColor: C.bad })
          Text(t('重试'))
            .fontSize(8.5)
            .fontColor(C.acc)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#2a1a1a')
        .onClick(() => {
          this.err = false;
          this.load();
        })
      } else {
        Column() {
          LoadingProgress().width(12).height(12).color('#6f6a56')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      Column() {
        Text(`${this.pageNo}`)
          .fontSize(9)
          .fontFamily(FT.mono)
          .fontColor('#e8e3d6')
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .backgroundColor('#99000000')
          .borderRadius(3)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.End)
      .padding(3)
      .hitTestBehavior(HitTestMode.None)
    }
    .width(58)
    .height(82)
    .borderRadius(4)
    .clip(true)
    .backgroundColor('#cfc9b9')
    .border({ width: 2, color: this.err ? C.bad : (this.pageNo === this.curPage ? C.acc : '#00000000') })
  }
}

@Component
struct ComicStrip {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop bookId: string = '';
  @Prop pageNo: number = 0;
  @Prop useArchive: boolean = false;
  @Prop crop: boolean = false;
  @Prop enhance: boolean = false;
  @Prop pageWidth: number = 0;
  @Prop @Watch('onVersion') version: number = 0;
  @State pixmap: image.PixelMap | undefined = undefined;
  @State ratio: number = 1.4;
  @State err: string = '';

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.releasePixel();
  }

  onVersion(): void {
    this.err = '';
    this.releasePixel();
    this.load();
  }

  private releasePixel(): void {
    if (this.pixmap !== undefined) {
      this.pixmap.release();
      this.pixmap = undefined;
    }
  }

  private reasonOf(error: Error): string {
    const raw: string = error.message ?? '';
    if (raw.length === 0) {
      return t('页图加载失败');
    }
    return raw.length > 40 ? raw.substring(0, 40) + '…' : raw;
  }

  private async load(): Promise<void> {
    if (this.pageNo < 1) {
      return;
    }
    if (!this.useArchive && this.bookId.length === 0) {
      return;
    }
    try {
      let bytes: ArrayBuffer;
      if (this.useArchive) {
        const book: ArchiveBook | null = appStore.localArchive;
        if (book === null) {
          return;
        }
        bytes = await comicArchive.readPage(book, this.pageNo);
      } else {
        const local: ArrayBuffer | null = offlinePage(this.bookId, this.pageNo, 'jpeg');
        bytes = local !== null ? local : await appStore.api.page(this.bookId, this.pageNo, 'jpeg', this.pageWidth);
      }
      const source: image.ImageSource = image.createImageSource(bytes);
      try {
        const options: image.DecodingOptions = { editable: true };
        const pixel: image.PixelMap | undefined = await source.createPixelMap(options) as image.PixelMap | undefined;
        if (pixel === undefined) {
          throw new Error(t('页图解码失败'));
        }
        await ImageOps.tune(pixel, this.crop, this.enhance);
        const info: image.ImageInfo = await pixel.getImageInfo();
        if (info.size.height > 0) {
          this.ratio = info.size.width / info.size.height;
        }
        this.pixmap = pixel;
        this.err = '';
      } finally {
        source.release();
      }
    } catch (error) {
      this.pixmap = undefined;
      this.err = this.reasonOf(error as Error);
    }
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.pixmap !== undefined) {
          Image(this.pixmap)
            .width('100%')
            .aspectRatio(this.ratio)
            .objectFit(ImageFit.Contain)
        } else if (this.err.length > 0) {
          Stack() {
            Column()
              .width('100%')
              .aspectRatio(this.ratio)
              .backgroundColor('#141414')
            PageFailBox({
              pageNo: this.pageNo,
              reason: this.err,
              compact: false,
              onRetry: () => {
                this.err = '';
                this.load();
              }
            })
          }
          .width('100%')
          .aspectRatio(this.ratio)
        } else {
          Stack() {
            Column()
              .width('100%')
              .aspectRatio(this.ratio)
              .backgroundColor('#141414')
            LoadingProgress().width(22).height(22).color('#6f6a56')
          }
          .width('100%')
        }
      }
      .width('100%')

      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#1d2221')
    }
    .width('100%')
  }
}
