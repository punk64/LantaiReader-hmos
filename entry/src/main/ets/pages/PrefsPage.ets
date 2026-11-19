import { promptAction } from '@kit.ArkUI';
import { C, R, S } from '../common/Theme';
import { ActionBtn, GroupHead, ScreenHead, SegBar, ToggleRow } from '../components/Shell';
import { PrefKeys, Prefs } from '../model/Prefs';

import { t } from '../common/I18n';
@Component
export struct PrefsPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State cmMode: number = 0;
  @State cmFit: number = 0;
  @State cmQuality: number = 2;
  @State cmMargin: number = 2;
  @State cmDir: number = 0;
  @State fs: number = 18;
  @State lh: number = 18;
  @State measure: number = 34;
  @State ebFont: number = 0;
  @State ebTheme: number = 0;
  @State keepScreen: boolean = true;
  @State hideStatus: boolean = false;
  @State autoHide: boolean = true;
  @State prefSync: boolean = false;

  aboutToAppear(): void {
    this.cmMode = Prefs.int(PrefKeys.cmMode, 0);
    this.cmFit = Prefs.int(PrefKeys.cmFit, 0);
    this.cmQuality = Prefs.int(PrefKeys.cmQuality, 2);
    this.cmMargin = Prefs.int(PrefKeys.cmMargin, 2);
    this.cmDir = Prefs.int(PrefKeys.cmDir, 0);
    this.fs = Prefs.int(PrefKeys.fs, 18);
    this.lh = Prefs.int(PrefKeys.lh, 18);
    this.measure = Prefs.int(PrefKeys.measure, 34);
    this.ebFont = Prefs.int(PrefKeys.ebFont, 0);
    this.ebTheme = Prefs.int(PrefKeys.ebTheme, 0);
    this.keepScreen = Prefs.bool(PrefKeys.keepScreen, true);
    this.hideStatus = Prefs.bool(PrefKeys.hideStatus, false);
    this.autoHide = Prefs.bool(PrefKeys.autoHide, true);
    this.prefSync = Prefs.bool(PrefKeys.prefSync, false);
  }

  private async save(): Promise<void> {
    await Prefs.putInt(PrefKeys.cmMode, this.cmMode);
    await Prefs.putInt(PrefKeys.cmFit, this.cmFit);
    await Prefs.putInt(PrefKeys.cmQuality, this.cmQuality);
    await Prefs.putInt(PrefKeys.cmMargin, this.cmMargin);
    await Prefs.putInt(PrefKeys.cmDir, this.cmDir);
    await Prefs.putInt(PrefKeys.fs, this.fs);
    await Prefs.putInt(PrefKeys.lh, this.lh);
    await Prefs.putInt(PrefKeys.measure, this.measure);
    await Prefs.putInt(PrefKeys.ebFont, this.ebFont);
    await Prefs.putInt(PrefKeys.ebTheme, this.ebTheme);
    await Prefs.putBool(PrefKeys.keepScreen, this.keepScreen);
    await Prefs.putBool(PrefKeys.hideStatus, this.hideStatus);
    await Prefs.putBool(PrefKeys.autoHide, this.autoHide);
    await Prefs.putBool(PrefKeys.prefSync, this.prefSync);
    promptAction.showToast({ message: t('偏好已保存，下次打开阅读器生效') });
    this.nav.pop();
  }

  private async reset(): Promise<void> {
    const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: t('恢复默认'),
      message: t('所有阅读偏好回到初始值，本机已保存的设置会被覆盖。'),
      buttons: [
        { text: t('取消'), color: C.tx3 },
        { text: t('恢复'), color: C.bad }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    this.cmMode = 0;
    this.cmFit = 0;
    this.cmQuality = 2;
    this.cmMargin = 2;
    this.cmDir = 0;
    this.fs = 18;
    this.lh = 18;
    this.measure = 34;
    this.ebFont = 0;
    this.ebTheme = 0;
    this.keepScreen = true;
    this.hideStatus = false;
    this.autoHide = true;
    this.prefSync = false;
    await this.save();
  }

  @Builder
  label(text: string, gap: number) {
    Text(text)
      .fontSize(10.5)
      .fontColor(C.tx3)
      .width('100%')
      .margin({ top: gap, bottom: 8 })
  }

  @Builder
  fsRow() {
    Row({ space: 10 }) {
      Text(t('字号'))
        .fontSize(11)
        .fontColor(C.tx3)
        .width(36)
      Slider({ value: this.fs, min: 14, max: 26, step: 1, style: SliderStyle.OutSet })
        .layoutWeight(1)
        .selectedColor(C.acc)
        .trackColor(C.bg4)
        .blockColor(C.acc2)
        .onChange((value: number) => {
          this.fs = Math.round(value);
        })
      Text(`${this.fs}px`)
        .fontSize(10.5)
        .fontColor(C.tx2)
        .width(40)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  lhRow() {
    Row({ space: 10 }) {
      Text(t('行距'))
        .fontSize(11)
        .fontColor(C.tx3)
        .width(36)
      Slider({ value: this.lh, min: 14, max: 24, step: 1, style: SliderStyle.OutSet })
        .layoutWeight(1)
        .selectedColor(C.acc)
        .trackColor(C.bg4)
        .blockColor(C.acc2)
        .onChange((value: number) => {
          this.lh = Math.round(value);
        })
      Text((this.lh / 10).toFixed(1))
        .fontSize(10.5)
        .fontColor(C.tx2)
        .width(40)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  measureRow() {
    Row({ space: 10 }) {
      Text(t('版心宽'))
        .fontSize(11)
        .fontColor(C.tx3)
        .width(36)
      Slider({ value: this.measure, min: 26, max: 44, step: 1, style: SliderStyle.OutSet })
        .layoutWeight(1)
        .selectedColor(C.acc)
        .trackColor(C.bg4)
        .blockColor(C.acc2)
        .onChange((value: number) => {
          this.measure = Math.round(value);
        })
      Text(`${this.measure}`)
        .fontSize(10.5)
        .fontColor(C.tx2)
        .width(40)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      ScreenHead({
        title: t('阅读偏好'),
        sub: t('本机即时生效 · 可跨端同步'),
        back: t('我的'),
        action: t('保存'),
        onBack: () => {
          this.nav.pop();
        },
        onAction: () => {
          this.save();
        }
      })

      Scroll() {
        Column() {
          GroupHead({ title: t('漫画') })
          Column() {
            this.label(t('阅读模式'), 2)
            SegBar({
              options: [t('单页'), t('双页'), t('长条'), t('分页')],
              current: this.cmMode,
              onPick: (index: number) => {
                this.cmMode = index;
              }
            })
            this.label(t('画面适应'), 14)
            SegBar({
              options: [t('适应'), t('满宽'), t('满高'), t('原始')],
              current: this.cmFit,
              onPick: (index: number) => {
                this.cmFit = index;
              }
            })
            this.label(t('画质'), 14)
            SegBar({
              options: [t('省流'), t('标准'), t('高清')],
              current: this.cmQuality,
              onPick: (index: number) => {
                this.cmQuality = index;
              }
            })
            this.label(t('页边距'), 14)
            SegBar({
              options: [t('无'), t('窄'), t('标准'), t('宽')],
              current: this.cmMargin,
              onPick: (index: number) => {
                this.cmMargin = index;
              }
            })
            this.label(t('翻页方向'), 14)
            SegBar({
              options: [t('从左往右'), t('从右往左')],
              current: this.cmDir,
              onPick: (index: number) => {
                this.cmDir = index;
              }
            })
          }
          .width('100%')
          .padding(13)
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          GroupHead({ title: t('电子书') })
          Column() {
            this.fsRow()
            this.lhRow()
            this.measureRow()
            this.label(t('字体'), 14)
            SegBar({
              options: [t('宋体'), t('黑体'), t('楷体'), t('原书字体')],
              current: this.ebFont,
              onPick: (index: number) => {
                this.ebFont = index;
              }
            })
            this.label(t('纸张主题'), 14)
            SegBar({
              options: [t('纸白'), t('旧纸'), t('夜读')],
              current: this.ebTheme,
              onPick: (index: number) => {
                this.ebTheme = index;
              }
            })
          }
          .width('100%')
          .padding(13)
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          GroupHead({ title: t('通用') })
          Column() {
            ToggleRow({
              glyph: 'sun',
              title: t('保持屏幕常亮'),
              sub: t('阅读期间不自动锁屏'),
              isOn: this.keepScreen,
              onSwitch: (value: boolean) => {
                this.keepScreen = value;
              }
            })
            ToggleRow({
              glyph: 'eyeOff',
              title: t('隐藏状态栏'),
              sub: t('沉浸式全屏阅读'),
              isOn: this.hideStatus,
              onSwitch: (value: boolean) => {
                this.hideStatus = value;
              }
            })
            ToggleRow({
              glyph: 'grid',
              title: t('工具栏自动收起'),
              sub: t('3.2 秒无操作后淡出，按住时暂停计时'),
              isOn: this.autoHide,
              onSwitch: (value: boolean) => {
                this.autoHide = value;
              }
            })
            ToggleRow({
              glyph: 'sync',
              title: t('跨端同步阅读偏好'),
              sub: t('写入服务端 client-settings · 关闭时仅存本机'),
              isOn: this.prefSync,
              onSwitch: (value: boolean) => {
                this.prefSync = value;
              }
            })
          }
          .width('100%')
          .padding({ left: 13, right: 13 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          Row({ space: 10 }) {
            ActionBtn({ label: t('恢复默认'), onTap: () => {
              this.reset();
            } })
            ActionBtn({ label: t('保存'), primary: true, onTap: () => {
              this.save();
            } })
          }
          .width('100%')
          .margin({ top: 12 })

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
