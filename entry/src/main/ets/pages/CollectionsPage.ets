import { promptAction } from '@kit.ArkUI';
import { C, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { ProgressMarks } from '../common/ProgressMarks';
import { CoverImage } from '../components/CoverImage';
import { GroupHead, ScreenHead } from '../components/Shell';
import { EmptyView, ErrorView, LoadingView } from '../components/StateViews';
import { appStore } from '../model/AppStore';
import { BookItem, BookPage, BookQuery, CollectionCard, emptyQuery } from '../model/LantaiModels';

import { t } from '../common/I18n';
const TINTS: string[][] = [
  ['#2c3a3a', '#101919'],
  ['#3a2c2c', '#191313'],
  ['#2b3340', '#121721'],
  ['#333c2c', '#171b12'],
  ['#3a3340', '#181420'],
  ['#2c3a35', '#101915']
];

@Component
struct CollectionTile {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop item: CollectionCard = {} as CollectionCard;
  @Prop tint: number = 0;
  onTap: () => void = () => {};

  private initial(): string {
    return this.item.name.length > 0 ? this.item.name.substring(0, 1) : t('集');
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        Row() {
          Text(this.initial())
            .fontSize(30)
            .fontColor('#d6c9a8')
            .opacity(0.5)
        }
        .width('100%')
        .height(84)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Text(this.item.seriesCount > 0 ? t(`${this.item.seriesCount} 个系列`) : t('空系列合集'))
          .fontSize(9)
          .fontColor('#918a76')
          .padding({ left: 12, right: 12, bottom: 9 })
      }
      .width('100%')
      .height(84)
      .linearGradient({
        angle: 140,
        colors: [[TINTS[this.tint % TINTS.length][0], 0], [TINTS[this.tint % TINTS.length][1], 1]]
      })

      Column({ space: 2 }) {
        Text(this.item.name)
          .fontSize(13.5)
          .fontColor(C.tx)
          .letterSpacing(0.5)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.item.at.length > 0 ? F.ago(this.item.at) : t('未记录时间'))
          .fontSize(9.5)
          .fontColor(C.tx4)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, right: 12, top: 9, bottom: 10 })
    }
    .width('100%')
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .clip(true)
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
struct RecentRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('progressVer') @Watch('onMarks') progressVer: number = 0;
  @State marksTick: number = 0;
  @Prop book: BookItem = {} as BookItem;
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
    Row({ space: 12 }) {
      CoverImage({ bookId: this.book.id, title: this.book.title, coverWidth: 44, coverHeight: 62, radius: 4 })
      Column({ space: 4 }) {
        Text(this.book.title)
          .fontSize(12.5)
          .fontColor(C.tx)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${this.book.authors.length > 0 ? this.book.authors : this.book.profile} · ${F.ago(this.book.created)}`)
          .fontSize(9.5)
          .fontColor(C.tx4)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(F.progressLabel(this.page(), this.book.pages, this.done()))
          .fontSize(9.5)
          .fontColor(this.done() ? C.ok : C.tx4)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(14)
        .fontColor(C.tx4)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
export struct CollectionsPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State items: CollectionCard[] = [];
  @State recent: BookItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State opening: boolean = false;

  aboutToAppear(): void {
    this.reload();
  }

  private async reload(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      this.items = await appStore.api.collections();
    } catch (error) {
      this.items = [];
      this.error = (error as Error).message;
    }
    this.loading = false;
    try {
      const query: BookQuery = emptyQuery();
      query.size = 4;
      query.sort = 'created,desc';
      const page: BookPage = await appStore.api.books(query);
      this.recent = page.items;
    } catch (error) {
      this.recent = [];
    }
  }

  private async open(item: CollectionCard): Promise<void> {
    if (this.opening) {
      return;
    }
    this.opening = true;
    try {
      const seriesId: string = await appStore.api.collectionFirstSeries(item.id);
      if (seriesId.length === 0) {
        promptAction.showToast({ message: t('这个系列合集里还没有系列') });
      } else {
        appStore.selectedSeriesId = seriesId;
        this.nav.pushPathByName('series', null);
      }
    } catch (error) {
      promptAction.showToast({ message: t(`打开失败：${(error as Error).message}`) });
    }
    this.opening = false;
  }

  private totalSeries(): number {
    let total: number = 0;
    for (let index: number = 0; index < this.items.length; index++) {
      total += this.items[index].seriesCount;
    }
    return total;
  }

  build() {
    Column() {
      ScreenHead({
        title: t('系列合集'),
        sub: this.items.length > 0 ? t(`${this.items.length} 个系列合集 · 合计 ${this.totalSeries()} 个系列`) : t('按系列归集'),
        back: t('我的'),
        onBack: () => {
          this.nav.pop();
        }
      })

      Scroll() {
        Column() {
          if (this.loading) {
            Column() {
              LoadingView({ label: t('读取系列合集') })
            }
            .width('100%')
            .height(240)
          } else if (this.error.length > 0) {
            Column() {
              ErrorView({ message: this.error, onRetry: () => {
                this.reload();
              } })
            }
            .width('100%')
            .height(240)
          } else if (this.items.length === 0) {
            EmptyView({
              title: t('服务端还没有系列合集'),
              hint: t('系列合集来自 Calibre 的 Collection 字段或服务端手动建立，建立后这里会自动出现'),
              glyph: 'grid'
            })
          } else {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              ForEach(this.items, (item: CollectionCard, index: number) => {
                Column() {
                  CollectionTile({
                    item: item,
                    tint: index,
                    onTap: () => {
                      this.open(item);
                    }
                  })
                }
                .width('48.5%')
                .margin({ bottom: 10 })
              }, (item: CollectionCard, index: number) => `${index}-${item.id}-${item.seriesCount}`)
            }
            .width('100%')
          }

          if (this.recent.length > 0) {
            GroupHead({ title: t('最近加入'), meta: t(`${this.recent.length} 册`) })
            Column() {
              ForEach(this.recent, (book: BookItem) => {
                RecentRow({
                  book: book,
                  onTap: () => {
                    appStore.selected = book;
                    this.nav.pushPathByName('book', null);
                  }
                })
              }, (book: BookItem) => `${book.id}-${book.created}`)
            }
            .width('100%')
            .padding({ left: 13, right: 13 })
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
