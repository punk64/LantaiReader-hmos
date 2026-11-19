import { image } from '@kit.ImageKit';
import { CoverCache } from './CoverCache';
import { C } from '../common/Theme';

import { t } from '../common/I18n';
const TINTS: string[][] = [
  ['#2c3a3a', '#101919'],
  ['#3a2c2c', '#191313'],
  ['#2b3340', '#121721'],
  ['#333c2c', '#171b12'],
  ['#3a3428', '#191710'],
  ['#2f2b3a', '#141220']
];

@Component
export struct CoverImage {
  @StorageLink('uiTick') @Watch('onTick') uiTick: number = 0;
  @Prop @Watch('onKey') bookId: string = '';
  @Prop title: string = '';
  @Prop @Watch('onKey') series: boolean = false;
  @Prop coverWidth: number = 96;
  @Prop coverHeight: number = 138;
  @Prop radius: number = 6;
  @State pix: image.PixelMap | undefined = undefined;
  @State failed: boolean = false;
  private retried: boolean = false;
  private disposed: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.disposed = true;
  }

  private onTick(): void {
    if (!this.disposed && this.pix === undefined) {
      this.load();
    }
  }

  private onKey(): void {
    if (this.disposed) {
      return;
    }
    this.pix = undefined;
    this.failed = false;
    this.retried = false;
    this.load();
  }

  private tint(): string[] {
    let hash: number = 0;
    for (let index = 0; index < this.bookId.length; index++) {
      hash = (hash + this.bookId.charCodeAt(index)) % 97;
    }
    return TINTS[hash % TINTS.length];
  }

  private initial(): string {
    return this.title.length > 0 ? this.title.substring(0, 1) : t('书');
  }

  private load(): void {
    if (this.bookId.length === 0) {
      return;
    }
    const hit: image.PixelMap | undefined = this.series ? CoverCache.cachedSeries(this.bookId) : CoverCache.cached(this.bookId);
    if (hit !== undefined) {
      this.pix = hit;
      return;
    }
    const requestWidth: number = Math.max(160, Math.round(this.coverWidth * 2));
    CoverCache.load(this.bookId, requestWidth, this.series)
      .then((pix: image.PixelMap) => {
        this.pix = pix;
        this.failed = false;
      })
      .catch((error: Error) => {
        this.failed = true;
        if (!this.retried && !this.disposed) {
          this.retried = true;
          setTimeout(() => {
            if (!this.disposed && this.pix === undefined) {
              this.load();
            }
          }, 2500);
        }
      });
  }

  build() {
    Stack() {
      if (this.pix !== undefined) {
        Image(this.pix)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .draggable(false)
      } else {
        Column() {
          Text(this.initial())
            .fontSize(Math.max(16, this.coverWidth * 0.42))
            .fontColor(this.failed ? C.tx4 : '#c9c3b2')
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .linearGradient({
          angle: 140,
          colors: [[this.tint()[0], 0], [this.tint()[1], 1]]
        })
      }
    }
    .width(this.coverWidth)
    .height(this.coverHeight)
    .borderRadius(this.radius)
    .clip(true)
    .backgroundColor(C.bg3)
  }
}
