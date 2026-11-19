import { C, R } from '../common/Theme';
import { F } from '../common/Format';
import { ProgressMarks } from '../common/ProgressMarks';
import { BookItem, emptyBook, profileLabel } from '../model/LantaiModels';
import { CoverImage } from './CoverImage';

import { t } from '../common/I18n';
@Component
export struct CoverProgress {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop percent: number = 0;
  @Prop barHeight: number = 3;

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(this.barHeight)
        .backgroundColor(this.percent > 0 ? '#4DFFFFFF' : '#26FFFFFF')
      if (this.percent > 0) {
        Row()
          .width(`${Math.min(100, Math.max(1, this.percent))}%`)
          .height(this.barHeight)
          .backgroundColor(C.acc)
      }
    }
    .width('100%')
    .height(this.barHeight)
  }
}

@Component
export struct BookRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('progressVer') @Watch('onMarks') progressVer: number = 0;
  @State marksTick: number = 0;
  @Prop book: BookItem = emptyBook();
  @Prop showProgress: boolean = true;
  @Prop showSeries: boolean = true;
  @Prop seriesBooks: number = 0;
  @Prop seriesRead: number = 0;
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

  private meta(): string {
    const parts: string[] = [];
    if (this.showSeries && this.book.seriesTitle.length > 0) {
      parts.push(this.book.seriesTitle);
    }
    parts.push(profileLabel(this.book.profile, this.book.mediaStatus));
    if (this.book.pages > 0) {
      parts.push(t(`${this.book.pages} 页`));
    }
    return parts.join(' · ');
  }

  private progressText(): string {
    const own: string = F.progressLabel(this.page(), this.book.pages, this.done());
    if (this.seriesBooks <= 0) {
      return own;
    }
    return t(`${own} · 系列 ${this.seriesRead}/${this.seriesBooks}`);
  }

  build() {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        CoverImage({
          bookId: this.book.id,
          title: this.book.title,
          coverWidth: 58,
          coverHeight: 82,
          radius: 5
        })
        if (this.showProgress) {
          CoverProgress({
            percent: this.done() ? 100 : F.percent(this.page(), this.book.pages),
            barHeight: 3
          })
        }
      }
      .width(58)
      .height(82)
      .borderRadius(5)
      .clip(true)

      Column() {
        Text(this.book.title)
          .fontSize(13)
          .lineHeight(18)
          .fontColor(C.tx)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .height(36)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.meta())
          .fontSize(10.5)
          .fontColor(C.tx3)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })

        Blank()

        Text(this.progressText())
          .fontSize(10.5)
          .fontColor(this.done() ? C.ok : C.tx3)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .height(82)
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
export struct BookGridCell {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('progressVer') @Watch('onMarks') progressVer: number = 0;
  @State marksTick: number = 0;
  @Prop book: BookItem = emptyBook();
  @Prop cellWidth: number = 104;
  @Prop seriesBooks: number = 0;
  @Prop seriesRead: number = 0;
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

  private progressText(): string {
    const own: string = F.progressLabel(this.page(), this.book.pages, this.done());
    if (this.seriesBooks <= 0) {
      return own;
    }
    return t(`${own} · 系列 ${this.seriesRead}/${this.seriesBooks}`);
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        CoverImage({
          bookId: this.book.id,
          title: this.book.title,
          coverWidth: this.cellWidth,
          coverHeight: this.cellWidth * 1.42,
          radius: 6
        })
        CoverProgress({
          percent: this.done() ? 100 : F.percent(this.page(), this.book.pages),
          barHeight: 3
        })
      }
      .width(this.cellWidth)
      .height(this.cellWidth * 1.42)
      .borderRadius(6)
      .clip(true)

      Text(this.book.title)
        .fontSize(11.5)
        .lineHeight(15)
        .fontColor(C.tx)
        .maxLines(2)
        .height(30)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })
      Text(this.book.seriesTitle.length > 0 ? this.book.seriesTitle : profileLabel(this.book.profile, this.book.mediaStatus))
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
        .fontColor(this.done() ? C.ok : C.tx4)
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
export struct FormatBadge {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop tone: string = 'normal';

  build() {
    Text(this.label)
      .fontSize(9)
      .fontColor(this.tone === 'done' ? C.ok : C.tx3)
      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
      .borderRadius(3)
      .border({ width: 1, color: this.tone === 'done' ? C.ok : C.line2 })
  }
}

@Component
export struct Chip {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop active: boolean = false;
  @Prop count: number = -1;
  @Prop compact: boolean = false;
  onTap: () => void = () => {};

  build() {
    Row({ space: 4 }) {
      Text(this.label)
        .fontSize(this.compact ? 10.5 : 11)
        .fontColor(this.active ? C.acc2 : C.tx3)
      if (this.count >= 0) {
        Text(`${this.count}`).fontSize(9).fontColor(this.active ? C.acc2 : C.tx4)
      }
    }
    .height(this.compact ? 24 : 28)
    .padding({ left: this.compact ? 9 : 11, right: this.compact ? 9 : 11 })
    .backgroundColor(this.active ? C.accBg : C.bg2)
    .borderRadius(this.compact ? 12 : 14)
    .border({ width: 1, color: this.active ? C.accLine : C.line })
    .onClick(() => {
      this.onTap();
    })
  }
}
