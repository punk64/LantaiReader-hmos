import { image } from '@kit.ImageKit';
import { promptAction } from '@kit.ArkUI';
import { textToSpeech } from '@kit.CoreSpeechKit';
import { ttsService } from '../net/TtsService';
import { appStore } from '../model/AppStore';
import { CoverCache } from './CoverCache';
import { ProgressMarks } from '../common/ProgressMarks';
import { readingTracker } from '../net/ReadingSession';

import { t } from '../common/I18n';
import { C } from '../common/Theme';
const BAR_H: number = 56;
const W_OFF: number = 56;
const W_ON: number = 280;
const EDGE: number = 10;
const TOP_PAD: number = 44;
const BOT_PAD: number = 56;
const BALL_W: number = 40;
const BALL_CRIM: number = 40;
const BALL_CDARK: number = 38.6;
const BALL_CGOLD: number = 37.2;
const BALL_CGAP: number = 33;
const BALL_CPIC: number = 30.4;
const BALL_RIM: number = 56;
const BALL_DARK: number = 53.6;
const BALL_GOLD: number = 51.2;
const BALL_GAP: number = 46;
const BALL_PIC: number = 43;
const BALL_BADGE: number = 21;
const IDLE_MS: number = 2000;
const RIM_LIGHT: string = '#B8FFFFFF';
const RIM_DARK: string = '#66000000';

@Component
struct PlayMark {
  @Prop on: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row({ space: 3 }) {
        Column().width(3.2).height(11).borderRadius(1.2).backgroundColor('#FFFFFF')
        Column().width(3.2).height(11).borderRadius(1.2).backgroundColor('#FFFFFF')
      }
      .opacity(this.on ? 1 : 0)
      .scale({ x: this.on ? 1 : 0.7, y: this.on ? 1 : 0.7 })

      Polygon({ width: 10, height: 12 })
        .points([[0, 0], [0, 12], [10, 6]])
        .fill('#FFFFFF')
        .margin({ left: 2.4 })
        .opacity(this.on ? 0 : 1)
        .scale({ x: this.on ? 0.7 : 1, y: this.on ? 0.7 : 1 })
    }
    .width(16)
    .height(14)
    .animation({ duration: 170, curve: Curve.FastOutSlowIn })
  }
}

@Component
export struct TtsBar {
  onOpenReader: () => void = () => {
  };
  @StorageLink('uiTick') @Watch('syncRing') uiTick: number = 0;
  @StorageLink('ttsBarOn') @Watch('onVisible') visible: boolean = false;
  @StorageLink('ttsBarIdx') idx: number = 0;
  @StorageLink('ttsBarTotal') total: number = 0;
  @StorageLink('ttsBarPlay') @Watch('syncRing') playing: boolean = false;
  @StorageLink('ttsBarKey') tick: number = 0;
  @State ring: string = '#E3C377';
  @State px: number = EDGE;
  @State py: number = 240;
  @State open: boolean = false;
  @State dragging: boolean = false;
  @State boxW: number = 0;
  @State boxH: number = 0;
  @State pix: image.PixelMap | undefined = undefined;
  @State voices: textToSpeech.VoiceInfo[] = [];
  @State @Watch('onVoice') voiceOpen: boolean = false;
  @State voiceState: string = '';
  @State toneNow: number = 0;
  private side: string = 'R';
  private ratio: number = 0.42;
  private placed: boolean = false;
  private baseX: number = 0;
  private baseY: number = 0;
  private coverId: string = '';
  private idleTimer: number = -1;
  private snapTimer: number = -1;

  aboutToAppear(): void {
    this.toneNow = ttsService.toneNow();
    this.syncRing();
    if (this.visible) {
      this.loadCover();
    }
  }

  private syncRing(): void {
    if (this.playing) {
      this.ring = C.mode === 'light' ? '#8A651F' : '#E8C46A';
    } else {
      this.ring = C.mode === 'light' ? '#B08A3A' : '#E3C377';
    }
  }

  aboutToDisappear(): void {
    this.clearIdle();
    this.clearSnap();
    this.releaseCover();
  }

  private onVisible(): void {
    if (this.visible) {
      this.loadCover();
      this.resetPlace();
      this.armIdle();
    } else {
      this.voiceOpen = false;
      this.clearIdle();
      this.clearSnap();
    }
  }

  private resetPlace(): void {
    this.side = 'R';
    this.ratio = 0.42;
    this.open = false;
    this.place();
  }

  private onVoice(): void {
    if (this.voiceOpen) {
      this.clearIdle();
      this.clearSnap();
    } else {
      this.armIdle();
    }
  }

  private clearIdle(): void {
    if (this.idleTimer >= 0) {
      clearTimeout(this.idleTimer);
      this.idleTimer = -1;
    }
  }

  private clearSnap(): void {
    if (this.snapTimer >= 0) {
      clearTimeout(this.snapTimer);
      this.snapTimer = -1;
    }
  }

  private armIdle(): void {
    this.clearIdle();
    if (!this.visible || !this.open || this.voiceOpen) {
      return;
    }
    this.idleTimer = setTimeout(() => {
      this.idleTimer = -1;
      if (!this.visible || !this.open) {
        return;
      }
      if (this.voiceOpen) {
        this.armIdle();
        return;
      }
      this.recycle();
    }, IDLE_MS);
  }

  private loadCover(): void {
    const id: string = appStore.readerBookId;
    if (id.length === 0) {
      return;
    }
    if (id === this.coverId && this.pix !== undefined) {
      return;
    }
    this.coverId = id;
    this.releaseCover();
    CoverCache.own(id, 240)
      .then((pix: image.PixelMap) => {
        if (this.coverId !== id) {
          pix.release();
          return;
        }
        this.pix = pix;
      })
      .catch(() => {
      });
  }

  private releaseCover(): void {
    const old: image.PixelMap | undefined = this.pix;
    this.pix = undefined;
    if (old !== undefined) {
      old.release();
    }
  }

  private numOf(v: Length): number {
    if (typeof v === 'number') {
      return v as number;
    }
    if (typeof v === 'string') {
      const n: number = parseFloat(v as string);
      return isNaN(n) ? 0 : n;
    }
    return 0;
  }

  private widthNow(): number {
    return this.open ? W_ON : W_OFF;
  }

  private maxY(): number {
    return Math.max(TOP_PAD, this.boxH - BAR_H - BOT_PAD);
  }

  private clamp(v: number, lo: number, hi: number): number {
    if (hi < lo) {
      return lo;
    }
    return v < lo ? lo : (v > hi ? hi : v);
  }

  private place(): void {
    if (this.boxW <= 0 || this.boxH <= 0) {
      return;
    }
    const w: number = this.widthNow();
    const room: number = this.maxY() - TOP_PAD;
    const ty: number = TOP_PAD + this.ratio * (room > 0 ? room : 0);
    this.px = this.side === 'R' ? Math.max(EDGE, this.boxW - w - EDGE) : EDGE;
    this.py = this.clamp(ty, TOP_PAD, this.maxY());
  }

  private anchorX(w: number): number {
    if (this.boxW <= 0) {
      return this.px;
    }
    return this.side === 'R' ? Math.max(EDGE, this.boxW - w - EDGE) : EDGE;
  }

  private expand(): void {
    if (this.open) {
      return;
    }
    this.clearIdle();
    this.clearSnap();
    this.side = this.px + W_OFF / 2 < this.boxW / 2 ? 'L' : 'R';
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.open = true;
      this.px = this.anchorX(W_ON);
    });
    this.armIdle();
  }

  private collapse(): void {
    if (!this.open) {
      return;
    }
    this.clearIdle();
    this.clearSnap();
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.open = false;
      this.px = this.anchorX(W_OFF);
    });
  }

  private recycle(): void {
    if (!this.open) {
      return;
    }
    this.clearIdle();
    this.clearSnap();
    const left: boolean = this.px + W_ON / 2 < this.boxW / 2;
    this.side = left ? 'L' : 'R';
    animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.open = false;
      this.px = left ? EDGE : Math.max(EDGE, this.boxW - W_OFF - EDGE);
    });
    const room: number = this.maxY() - TOP_PAD;
    this.ratio = room > 0 ? this.clamp((this.py - TOP_PAD) / room, 0, 1) : 0.42;
  }

  private snap(): void {
    this.clearSnap();
    const w: number = this.widthNow();
    const left: boolean = this.px + w / 2 < this.boxW / 2;
    this.side = left ? 'L' : 'R';
    animateTo({ duration: 220, curve: Curve.Friction }, () => {
      this.px = left ? EDGE : Math.max(EDGE, this.boxW - w - EDGE);
    });
    const room: number = this.maxY() - TOP_PAD;
    this.ratio = room > 0 ? this.clamp((this.py - TOP_PAD) / room, 0, 1) : 0.42;
  }

  private close(): void {
    this.clearIdle();
    this.clearSnap();
    ttsService.stop();
    ProgressMarks.flush();
    readingTracker.stop();
    this.open = false;
  }

  private readyOf(v: textToSpeech.VoiceInfo): boolean {
    return v.status === 'INSTALLED';
  }

  private labelOf(v: textToSpeech.VoiceInfo): string {
    const name: string = v.description ? v.description : '';
    return name.length > 0 ? name : `${t('音色')} ${v.person}`;
  }

  private langOf(v: textToSpeech.VoiceInfo): string {
    return v.language ? v.language : '';
  }

  private openVoices(): void {
    this.toneNow = ttsService.toneNow();
    this.voices = ttsService.voiceList().slice();
    this.voiceState = this.voices.length > 0 ? 'done' : 'loading';
    this.voiceOpen = true;
    if (this.voices.length === 0) {
      this.reloadVoices();
    }
  }

  private reloadVoices(): void {
    ttsService.refreshVoices().then(() => {
      this.voices = ttsService.voiceList().slice();
      this.voiceState = this.voices.length > 0 ? 'done' : 'empty';
    });
  }

  private pickVoice(v: textToSpeech.VoiceInfo): void {
    if (!this.readyOf(v)) {
      promptAction.showToast({ message: t('该音色需先在系统语音设置中下载'), duration: 1800 });
      return;
    }
    this.toneNow = v.person;
    ttsService.setTone(v.person);
    promptAction.showToast({ message: `${t('已切换音色')} · ${this.labelOf(v)}`, duration: 1500 });
    this.voiceOpen = false;
  }

  @Styles
  pressFx() {
    .scale({ x: 0.92, y: 0.92 })
    .opacity(0.82)
  }

  @Builder
  knob(label: string, size: number, color: string, w: number, act: () => void) {
    Text(label)
      .fontSize(size)
      .fontColor(color)
      .width(w)
      .height(BAR_H)
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .onClick(() => {
        this.armIdle();
        act();
      })
      .stateStyles({ pressed: this.pressFx })
  }

  @Builder
  badge() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(BALL_BADGE)
        .height(BALL_BADGE)
        .borderRadius(BALL_BADGE / 2)
        .backgroundColor(this.playing ? '#E8C46A' : '#F4F1EA')
        .border({ width: 1.8, color: '#1C1C1E' })
      if (this.playing) {
        Row({ space: 2.4 }) {
          Column().width(2.6).height(9).borderRadius(1).backgroundColor('#1C1C1E')
          Column().width(2.6).height(9).borderRadius(1).backgroundColor('#1C1C1E')
        }
      } else {
        Polygon({ width: 8, height: 10 })
          .points([[0, 0], [0, 10], [8, 5]])
          .fill('#1C1C1E')
          .margin({ left: 1.6 })
      }
    }
    .width(BALL_BADGE)
    .height(BALL_BADGE)
    .position({ x: 31, y: 31 })
    .shadow({ radius: 4, color: '#66000000', offsetY: 1 })
  }

  @Builder
  ball() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(BALL_RIM)
        .height(BALL_RIM)
        .borderRadius(BALL_RIM / 2)
        .backgroundColor(RIM_LIGHT)
      Column()
        .width(BALL_DARK)
        .height(BALL_DARK)
        .borderRadius(BALL_DARK / 2)
        .backgroundColor(RIM_DARK)
      Column()
        .width(BALL_GOLD)
        .height(BALL_GOLD)
        .borderRadius(BALL_GOLD / 2)
        .backgroundColor(this.ring)
      Column()
        .width(BALL_GAP)
        .height(BALL_GAP)
        .borderRadius(BALL_GAP / 2)
        .backgroundColor('#1C1C1E')
      Stack({ alignContent: Alignment.Center }) {
        if (this.pix !== undefined) {
          Image(this.pix)
            .width(BALL_PIC)
            .height(BALL_PIC)
            .objectFit(ImageFit.Cover)
            .draggable(false)
          Column()
            .width(BALL_PIC)
            .height(BALL_PIC)
            .backgroundColor('#73000000')
        } else {
          Text('♪')
            .fontSize(16)
            .fontColor('#D8D8DC')
        }
        Progress({
          value: Math.max(1, this.idx + 1),
          total: Math.max(1, this.total),
          type: ProgressType.Ring
        })
          .width(BALL_PIC - 10)
          .height(BALL_PIC - 10)
          .color(this.playing ? '#E8C46A' : '#9A9A9E')
          .backgroundColor('#33FFFFFF')
          .style({ strokeWidth: 2.4 })
          .animation({ duration: 220, curve: Curve.FastOutSlowIn })
      }
      .width(BALL_PIC)
      .height(BALL_PIC)
      .borderRadius(BALL_PIC / 2)
      .clip(true)
      this.badge()
    }
    .width(W_OFF)
    .height(BAR_H)
    .stateStyles({ pressed: this.pressFx })
    .onClick((ev: ClickEvent) => {
      if (ev.x > 30 && ev.y > 30) {
        this.armIdle();
        if (this.playing) {
          ttsService.pause();
        } else {
          ttsService.resume();
        }
        return;
      }
      this.expand();
    })
  }

  @Builder
  coverBall() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(BALL_CRIM)
        .height(BALL_CRIM)
        .borderRadius(BALL_CRIM / 2)
        .backgroundColor(RIM_LIGHT)
      Column()
        .width(BALL_CDARK)
        .height(BALL_CDARK)
        .borderRadius(BALL_CDARK / 2)
        .backgroundColor(RIM_DARK)
      Column()
        .width(BALL_CGOLD)
        .height(BALL_CGOLD)
        .borderRadius(BALL_CGOLD / 2)
        .backgroundColor(this.ring)
      Column()
        .width(BALL_CGAP)
        .height(BALL_CGAP)
        .borderRadius(BALL_CGAP / 2)
        .backgroundColor('#1C1C1E')
      Stack({ alignContent: Alignment.Center }) {
        if (this.pix !== undefined) {
          Image(this.pix)
            .width(BALL_CPIC)
            .height(BALL_CPIC)
            .objectFit(ImageFit.Cover)
            .draggable(false)
          Column()
            .width(BALL_CPIC)
            .height(BALL_CPIC)
            .backgroundColor('#5C000000')
        } else {
          Text('♪')
            .fontSize(13)
            .fontColor('#D8D8DC')
        }
      }
      .width(BALL_CPIC)
      .height(BALL_CPIC)
      .borderRadius(BALL_CPIC / 2)
      .clip(true)
    }
    .width(BALL_W)
    .height(BALL_W)
    .onClick(() => {
      this.collapse();
    })
  }

  @Builder
  pill() {
    Row() {
      this.coverBall()
      this.knob('‹', 22, '#FFFFFF', 30, () => {
        ttsService.seek(this.idx - 1);
      })
      Stack({ alignContent: Alignment.Center }) {
        PlayMark({ on: this.playing })
      }
      .width(42)
      .height(BAR_H)
      .onClick(() => {
        this.armIdle();
        if (this.playing) {
          ttsService.pause();
        } else {
          ttsService.resume();
        }
      })
      .stateStyles({ pressed: this.pressFx })
      this.knob('›', 22, '#FFFFFF', 30, () => {
        ttsService.seek(this.idx + 1);
      })
      Text(`${Math.max(1, this.idx + 1)}/${Math.max(1, this.total)}`)
        .fontSize(11)
        .fontColor('#B8B8B8')
        .width(54)
        .height(BAR_H)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .onClick(() => {
          this.armIdle();
          this.onOpenReader();
        })
        .stateStyles({ pressed: this.pressFx })
      Text(t('音色'))
        .fontSize(11)
        .fontColor('#E8C46A')
        .width(40)
        .height(BAR_H)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.armIdle();
          this.openVoices();
        })
        .bindSheet($$this.voiceOpen, this.voicePanel(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: false,
          showClose: false,
          backgroundColor: '#1C1C1E',
          onDisappear: () => {
            this.voiceOpen = false;
            this.armIdle();
          }
        })
      this.knob('×', 17, '#B8B8B8', 30, () => {
        this.close();
      })
    }
    .height(BAR_H)
    .padding({ left: 6, right: 6 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  voicePanel() {
    Column() {
      Row() {
        Text(t('朗读音色'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
        Text('✕')
          .fontSize(16)
          .fontColor('#B8B8B8')
          .onClick(() => {
            this.voiceOpen = false;
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 10 })

      if (this.voices.length === 0) {
        Column() {
          if (this.voiceState === 'loading') {
            LoadingProgress().width(22).height(22).color('#8A8A8E')
            Text(t('正在读取系统音色'))
              .fontSize(12)
              .fontColor('#8A8A8E')
              .margin({ top: 10 })
          } else {
            Text(t('没有读到系统音色'))
              .fontSize(12)
              .fontColor('#8A8A8E')
            Text(t('重试'))
              .fontSize(12)
              .fontColor('#E8C46A')
              .margin({ top: 12 })
              .onClick(() => {
                this.voiceState = 'loading';
                this.reloadVoices();
              })
          }
        }
        .width('100%')
        .height(150)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 2 }) {
          ForEach(this.voices, (v: textToSpeech.VoiceInfo) => {
            ListItem() {
              Row() {
                Column() {
                  Text(this.labelOf(v))
                    .fontSize(14)
                    .fontColor(this.readyOf(v) ? '#FFFFFF' : '#7A7A7E')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (!this.readyOf(v)) {
                    Text(`${this.langOf(v)} · ${t('需下载')}`)
                      .fontSize(10.5)
                      .fontColor('#8A8A8E')
                      .margin({ top: 2 })
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (v.person === this.toneNow) {
                  Text('✓')
                    .fontSize(15)
                    .fontColor('#E8C46A')
                }
              }
              .width('100%')
              .padding({ left: 18, right: 18, top: 11, bottom: 11 })
              .borderRadius(10)
              .backgroundColor(v.person === this.toneNow ? '#26E8C46A' : '#00000000')
              .onClick(() => {
                this.pickVoice(v);
              })
            }
          }, (v: textToSpeech.VoiceInfo) => `${v.person}`)
        }
        .width('100%')
        .constraintSize({ maxHeight: 400 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .padding({ bottom: 16 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.visible && this.placed) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.open) {
            this.pill()
          } else {
            this.ball()
          }
        }
        .width(this.widthNow())
        .height(BAR_H)
        .backgroundColor(this.pix !== undefined && !this.open ? '#00000000' : '#E61C1C1E')
        .borderRadius(BAR_H / 2)
        .border({ width: this.open ? 1 : 0, color: '#33FFFFFF' })
        .shadow({
          radius: this.playing && !this.open ? 22 : (this.dragging ? 26 : 18),
          color: this.playing && !this.open ? '#4DE8C46A' : (this.dragging ? '#66000000' : '#40000000'),
          offsetY: this.dragging ? 8 : 5
        })
        .scale({ x: this.dragging ? 1.04 : 1, y: this.dragging ? 1.04 : 1 })
        .animation({ duration: 260, curve: Curve.FastOutSlowIn })
        .clip(true)
        .position({ x: this.px, y: this.py })
        .gesture(
          PanGesture({ fingers: 1, distance: 4 })
            .onActionStart(() => {
              this.clearIdle();
              this.clearSnap();
              this.dragging = true;
              this.baseX = this.px;
              this.baseY = this.py;
            })
            .onActionUpdate((event: GestureEvent) => {
              const w: number = this.widthNow();
              this.px = this.clamp(this.baseX + event.offsetX, 0, Math.max(0, this.boxW - w));
              this.py = this.clamp(this.baseY + event.offsetY, TOP_PAD, this.maxY());
            })
            .onActionEnd(() => {
              this.dragging = false;
              if (this.open) {
                this.armIdle();
              } else {
                this.snap();
              }
            })
        )
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart)
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const w: number = this.numOf(newArea.width);
      const h: number = this.numOf(newArea.height);
      if (w <= 0 || h <= 0) {
        return;
      }
      this.boxW = w;
      this.boxH = h;
      if (!this.placed) {
        this.placed = true;
        this.place();
        this.armIdle();
      } else {
        this.px = this.clamp(this.px, 0, Math.max(0, w - this.widthNow()));
        this.py = this.clamp(this.py, TOP_PAD, this.maxY());
      }
    })
  }
}
