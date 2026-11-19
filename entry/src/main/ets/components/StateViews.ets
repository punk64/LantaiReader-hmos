import { C, FT } from '../common/Theme';
import { GlyphIcon } from './Icon';

import { t } from '../common/I18n';
@Component
export struct LoadingView {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = t('加载中');

  build() {
    Column({ space: 14 }) {
      LoadingProgress().width(34).height(34).color(C.acc)
      Text(this.label).fontSize(12).fontColor(C.tx3)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}

@Component
export struct EmptyView {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop title: string = t('暂无内容');
  @Prop hint: string = '';
  @Prop glyph: string = 'book';

  build() {
    Column({ space: 10 }) {
      GlyphIcon({ glyphName: this.glyph, glyphSize: 26, glyphColor: C.tx4, glyphWeight: 1.4 })
      Text(this.title)
        .fontSize(13)
        .fontColor(C.tx2)
        .textAlign(TextAlign.Center)
      if (this.hint.length > 0) {
        Text(this.hint)
          .fontSize(11)
          .fontColor(C.tx4)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 56, bottom: 56, left: 24, right: 24 })
    .justifyContent(FlexAlign.Center)
  }
}

@Component
export struct ErrorView {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop message: string = '';
  @Prop actionLabel: string = t('重试');
  onRetry: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text(this.message).fontSize(12).fontColor(C.bad).textAlign(TextAlign.Center)
      Button(this.actionLabel)
        .height(32)
        .fontSize(12)
        .backgroundColor(C.bg3)
        .fontColor(C.tx)
        .onClick(() => {
          this.onRetry();
        })
    }
    .width('100%')
    .padding({ top: 60, bottom: 60, left: 24, right: 24 })
    .justifyContent(FlexAlign.Center)
  }
}

@Component
export struct SectionHead {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop title: string = '';
  @Prop meta: string = '';
  @Prop action: string = '';
  onAction: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      Text(this.title)
        .fontSize(16)
        .fontFamily(FT.disp)
        .letterSpacing(1)
        .fontColor(C.tx)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.meta.length > 0) {
        Text(this.meta)
          .fontSize(10)
          .fontFamily(FT.mono)
          .fontColor(C.tx4)
      }
      Blank()
      if (this.action.length > 0) {
        Row({ space: 2 }) {
          Text(this.action)
            .fontSize(11)
            .fontColor(C.tx3)
          GlyphIcon({ glyphName: 'next', glyphSize: 13, glyphColor: C.tx3 })
        }
        .onClick(() => {
          this.onAction();
        })
      }
    }
    .width('100%')
    .padding({ top: 22, bottom: 11 })
  }
}

@Component
export struct ProgressBar {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop percent: number = 0;
  @Prop barHeight: number = 3;

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row().width('100%').height(this.barHeight).backgroundColor(C.bg4).borderRadius(this.barHeight)
      Row().width(`${Math.max(0, Math.min(100, this.percent))}%`).height(this.barHeight)
        .backgroundColor(C.acc).borderRadius(this.barHeight)
    }
    .width('100%')
  }
}
