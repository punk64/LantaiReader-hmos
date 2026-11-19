import { C, FT, R, S } from '../common/Theme';
import { GlyphIcon } from './Icon';

import { t } from '../common/I18n';
function isGlyphIcon(glyph: string): boolean {
  return glyph.length > 0 && glyph.charCodeAt(0) < 128;
}

export interface TabItem {
  label: string;
  glyph: string;
  icon: string;
}

export function tabs(): TabItem[] {
  return [
    { label: t('首页'), glyph: t('首'), icon: 'home' },
    { label: t('书库'), glyph: t('库'), icon: 'library' },
    { label: t('统计'), glyph: t('计'), icon: 'chart' },
    { label: t('我的'), glyph: t('我'), icon: 'user' }
  ];
}

@Component
export struct ScreenHead {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop title: string = '';
  @Prop sub: string = '';
  @Prop back: string = '';
  @Prop action: string = '';
  @Prop actionIcon: string = '';
  @Prop actionOn: boolean = false;
  @Prop actionIcon2: string = '';
  @Prop actionOn2: boolean = false;
  @Prop actionIcon3: string = '';
  @Prop actionOn3: boolean = false;
  @Prop brand: boolean = false;
  @Prop titleSize: number = 18;
  onBack: () => void = () => {};
  onAction: () => void = () => {};
  onAction2: () => void = () => {};
  onAction3: () => void = () => {};

  build() {
    Column() {
      if (this.back.length > 0) {
        Row() {
          Row({ space: 6 }) {
            GlyphIcon({ glyphName: 'back', glyphSize: 16, glyphColor: C.tx2 })
            Text(this.back)
              .fontSize(12.5)
              .fontColor(C.tx2)
          }
          .height(26)
          .padding({ left: 4, right: 6 })
          .borderRadius(8)
          .onClick(() => {
            this.onBack();
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ bottom: 4 })
      }

      Row({ space: 10 }) {
        if (this.brand) {
          Row({ space: 9 }) {
            Image($r('app.media.logo_lantai'))
              .width(31)
              .height(31)
              .borderRadius(9)
              .clip(true)
              .border({ width: 1, color: C.accLine })

            Column() {
              Text(t('兰台阅读'))
                .fontSize(17)
                .fontFamily(FT.disp)
                .letterSpacing(3)
                .fontColor(C.acc2)
              Text('LANTAI READER')
                .fontSize(8)
                .fontFamily(FT.mono)
                .letterSpacing(2)
                .fontColor(C.tx4)
                .margin({ top: 1 })
            }
            .alignItems(HorizontalAlign.Start)
          }
        } else {
          Text(this.title)
            .fontSize(this.titleSize)
            .fontFamily(FT.disp)
            .letterSpacing(1)
            .fontColor(C.tx)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }

        Blank()

        if (this.actionIcon3.length > 0) {
          Stack() {
            GlyphIcon({
              glyphName: this.actionIcon3,
              glyphSize: 17,
              glyphColor: this.actionOn3 ? C.acc2 : C.tx2
            })
          }
          .width(33)
          .height(33)
          .borderRadius(10)
          .backgroundColor(this.actionOn3 ? C.accBg : '#00000000')
          .onClick(() => {
            this.onAction3();
          })
        }

        if (this.actionIcon2.length > 0) {
          Stack() {
            GlyphIcon({
              glyphName: this.actionIcon2,
              glyphSize: 17,
              glyphColor: this.actionOn2 ? C.acc2 : C.tx2
            })
          }
          .width(33)
          .height(33)
          .borderRadius(10)
          .backgroundColor(this.actionOn2 ? C.accBg : '#00000000')
          .onClick(() => {
            this.onAction2();
          })
        }

        if (this.actionIcon.length > 0) {
          Stack() {
            GlyphIcon({ glyphName: this.actionIcon, glyphSize: 17, glyphColor: this.actionOn ? C.acc2 : C.tx2 })
          }
          .width(33)
          .height(33)
          .borderRadius(10)
          .backgroundColor(this.actionOn ? C.accBg : '#00000000')
          .border({ width: 1, color: this.actionOn ? C.accLine : '#00000000' })
          .onClick(() => {
            this.onAction();
          })
        }

        if (this.action.length > 0) {
          Text(this.action)
            .fontSize(11.5)
            .fontColor(C.acc)
            .padding({ left: 11, right: 11, top: 6, bottom: 6 })
            .backgroundColor(C.accBg)
            .borderRadius(R.s)
            .onClick(() => {
              this.onAction();
            })
        }
      }
      .width('100%')
      .constraintSize({ minHeight: 33 })
      .alignItems(VerticalAlign.Center)

      if (this.brand && this.title.length > 0) {
        Text(this.title)
          .fontSize(21)
          .fontFamily(FT.disp)
          .letterSpacing(1.2)
          .fontWeight(FontWeight.Medium)
          .fontColor(C.tx)
          .width('100%')
          .margin({ top: 8 })
      }

      if (this.sub.length > 0) {
        Text(this.sub)
          .fontSize(11.5)
          .fontColor(C.tx3)
          .width('100%')
          .margin({ top: 3 })
      }
    }
    .width('100%')
    .padding({ left: S.page, right: S.page, top: 12, bottom: 11 })
    .backgroundColor(C.glass)
    .border({ width: { bottom: 1 }, color: C.line })
  }
}

@Component
export struct BottomTabs {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop current: number = 0;
  onPick: (index: number) => void = () => {};
  @State gx: number = 0;
  @State gy: number = 0;
  @State gi: number = 0;
  @State press: number = 0;

  private glow(alpha: string): string {
    return `#${alpha}${C.acc.substring(1)}`;
  }

  private navGlass(): string {
    return C.navGlass;
  }

  private navShadow(): string {
    return `#66${C.shadow.substring(1)}`;
  }

  build() {
    Row() {
      Stack({ alignContent: Alignment.TopStart }) {
        Row()
          .width(152)
          .height(152)
          .borderRadius(76)
          .position({ x: this.gx - 76, y: this.gy - 76 })
          .opacity(this.gi)
          .radialGradient({
            center: ['50%', '50%'],
            radius: 76,
            colors: [[this.glow('F0'), 0], [this.glow('70'), 0.16],
              [this.glow('1F'), 0.5], [this.glow('00'), 1]]
          })

        Row() {
          ForEach(tabs(), (item: TabItem, index: number) => {
            Column({ space: 3 }) {
              Row()
                .width(18)
                .height(2)
                .borderRadius(1)
                .backgroundColor(index === this.current ? C.acc2 : '#00000000')
              GlyphIcon({
                glyphName: item.icon,
                glyphSize: 21,
                glyphColor: index === this.current ? C.acc2 : C.tx
              })
              Text(item.label)
                .fontSize(10)
                .letterSpacing(0.5)
                .fontColor(index === this.current ? C.acc2 : C.tx)
                .maxLines(1)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            .onClick(() => {
              this.onPick(index);
            })
          }, (item: TabItem, index: number) => `${index}-${item.label}`)
        }
        .width('100%')
        .height('100%')
        .padding({ top: 8, bottom: 9, left: 8, right: 8 })
      }
      .width('100%')
      .height('100%')
      .clip(true)
    }
    .width('100%')
    .height(64)
    .backgroundColor(this.navGlass())
    .backgroundEffect({ radius: 18, color: this.glow('0D'), saturation: 1.15 })
    .borderRadius(26)
    .border({ width: 1, color: C.navEdge })
    .shadow({ radius: 26, color: this.navShadow(), offsetX: 0, offsetY: 10 })
    .clip(true)
    .scale({ x: 1 - this.press * 0.012, y: 1 - this.press * 0.02 })
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.touches.length > 0) {
        this.gx = event.touches[0].x;
        this.gy = event.touches[0].y;
      }
      if (event.type === TouchType.Down) {
        this.gi = 1;
        this.press = 1;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.gi = 0;
        this.press = 0;
      }
    })
  }
}

@Component
export struct NavRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop glyph: string = '';
  @Prop title: string = '';
  @Prop sub: string = '';
  @Prop right: string = '';
  @Prop danger: boolean = false;
  onTap: () => void = () => {};

  build() {
    Row({ space: 11 }) {
      if (this.glyph.length > 0) {
        Stack() {
          if (isGlyphIcon(this.glyph)) {
            GlyphIcon({ glyphName: this.glyph, glyphSize: 15, glyphColor: this.danger ? C.bad : C.tx2 })
          } else {
            Text(this.glyph)
              .fontSize(10.5)
              .fontColor(this.danger ? C.bad : C.tx2)
          }
        }
        .width(30)
        .height(30)
        .backgroundColor(C.bg3)
        .borderRadius(8)
      }

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(12.5)
          .fontColor(this.danger ? C.bad : C.tx)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.sub.length > 0) {
          Text(this.sub)
            .fontSize(10)
            .fontColor(C.tx4)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.right.length > 0) {
        Text(this.right)
          .fontSize(10)
          .fontColor(C.tx4)
      }
      Text('›')
        .fontSize(14)
        .fontColor(C.tx4)
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
export struct ToggleRow {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop glyph: string = '';
  @Prop title: string = '';
  @Prop sub: string = '';
  @Prop isOn: boolean = false;
  onSwitch: (value: boolean) => void = () => {};

  build() {
    Row({ space: 11 }) {
      if (this.glyph.length > 0) {
        Stack() {
          if (isGlyphIcon(this.glyph)) {
            GlyphIcon({ glyphName: this.glyph, glyphSize: 15, glyphColor: C.tx2 })
          } else {
            Text(this.glyph)
              .fontSize(10.5)
              .fontColor(C.tx2)
          }
        }
        .width(30)
        .height(30)
        .backgroundColor(C.bg3)
        .borderRadius(8)
      }

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(12.5)
          .fontColor(C.tx)
          .width('100%')
        if (this.sub.length > 0) {
          Text(this.sub)
            .fontSize(10)
            .fontColor(C.tx4)
            .maxLines(2)
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor(C.acc)
        .switchPointColor(C.bg)
        .width(38)
        .height(22)
        .onChange((value: boolean) => {
          this.onSwitch(value);
        })
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
    .alignItems(VerticalAlign.Center)
  }
}

@Component
export struct Pill {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop tone: string = 'mute';

  private tint(): string {
    if (this.tone === 'done') {
      return C.ok;
    }
    if (this.tone === 'acc') {
      return C.acc2;
    }
    if (this.tone === 'warn') {
      return C.warn;
    }
    if (this.tone === 'bad') {
      return C.bad;
    }
    if (this.tone === 'info') {
      return C.info;
    }
    return C.tx3;
  }

  build() {
    Text(this.label)
      .fontSize(8.5)
      .fontColor(this.tint())
      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
      .borderRadius(3)
      .border({ width: 1, color: this.tint() })
  }
}

@Component
export struct SegBar {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop options: string[] = [];
  @Prop current: number = 0;
  onPick: (index: number) => void = () => {};

  build() {
    Row() {
      ForEach(this.options, (label: string, index: number) => {
        Text(label)
          .fontSize(11)
          .fontColor(index === this.current ? C.acc2 : C.tx3)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(27)
          .backgroundColor(index === this.current ? C.accBg : Color.Transparent)
          .borderRadius(7)
          .onClick(() => {
            this.onPick(index);
          })
      }, (label: string, index: number) => `${index}-${label}`)
    }
    .width('100%')
    .padding(3)
    .backgroundColor(C.bg2)
    .borderRadius(9)
    .border({ width: 1, color: C.line })
  }
}

@Component
export struct ActionBtn {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';
  @Prop primary: boolean = false;
  @Prop danger: boolean = false;
  @Prop glyph: string = '';
  onTap: () => void = () => {};

  private fg(): string {
    if (this.primary) {
      return C.onAcc;
    }
    return this.danger ? C.bad : C.tx2;
  }

  build() {
    Row({ space: 5 }) {
      if (this.glyph.length > 0) {
        if (isGlyphIcon(this.glyph)) {
          GlyphIcon({ glyphName: this.glyph, glyphSize: 14, glyphColor: this.fg() })
        } else {
          Text(this.glyph)
            .fontSize(10.5)
            .fontColor(this.fg())
        }
      }
      Text(this.label)
        .fontSize(12)
        .fontColor(this.fg())
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.primary ? C.acc : C.bg2)
    .borderRadius(10)
    .border({ width: 1, color: this.primary ? C.acc : (this.danger ? C.bad : C.line2) })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
export struct CardBox {
  @StorageLink('uiTick') uiTick: number = 0;
  @BuilderParam content: () => void;
  @Prop padH: number = 13;
  @Prop padV: number = 2;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding({ left: this.padH, right: this.padH, top: this.padV, bottom: this.padV })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
  }
}

@Component
export struct GroupHead {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop title: string = '';
  @Prop meta: string = '';
  @Prop action: string = '';
  onAction: () => void = () => {};

  build() {
    Row() {
      Text(this.title)
        .fontSize(14.5)
        .fontColor(C.tx)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(0.8)
      if (this.meta.length > 0) {
        Text(this.meta)
          .fontSize(9.5)
          .fontColor(C.tx4)
          .margin({ left: 7 })
      }
      Blank()
      if (this.action.length > 0) {
        Text(`${this.action} ›`)
          .fontSize(10.5)
          .fontColor(C.tx3)
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .padding({ top: 20, bottom: 9 })
  }
}

@Component
export struct NoteCard {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop text: string = '';

  build() {
    Row({ space: 8 }) {
      Text('i')
        .fontSize(9)
        .fontColor(C.tx4)
        .textAlign(TextAlign.Center)
        .width(15)
        .height(15)
        .borderRadius(8)
        .border({ width: 1, color: C.line2 })
        .margin({ top: 1 })
      Text(this.text)
        .fontSize(10)
        .fontColor(C.tx4)
        .lineHeight(17)
        .layoutWeight(1)
    }
    .width('100%')
    .padding(11)
    .alignItems(VerticalAlign.Top)
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
  }
}
