import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { C } from '../common/Theme';
import { ProgressMarks } from '../common/ProgressMarks';
import { WindowFx } from '../common/WindowFx';
import { appStore } from '../model/AppStore';
import { PrefKeys, Prefs } from '../model/Prefs';
import { bumpReaderWeb, readerWeb } from '../components/ReadingWeb';
import { ttsService } from '../net/TtsService';
import { readingTracker } from '../net/ReadingSession';

import { t } from '../common/I18n';

@Component
export struct ReaderPage {
  @Consume('nav') nav: NavPathStack;
  @StorageLink('readerBusy') busy: boolean = false;
  @State failed: string = '';
  private leaving: boolean = false;

  aboutToAppear(): void {
    appStore.backHook = () => this.onBackPressed();
    appStore.readerExitHook = () => this.leave();
    const bookId: string = appStore.readerBookId;
    if (bookId.length === 0) {
      this.failed = t('没有可打开的书');
      return;
    }
    if (!bookId.startsWith('local:')) {
      readingTracker.start(bookId, 0, appStore.readerIncognito);
    }
    if (ttsService.isPlaying() && readerWeb.bookId !== bookId) {
      ttsService.stop();
    }
    this.enter();
  }

  private async enter(): Promise<void> {
    const host: common.Context | undefined = this.getUIContext().getHostContext();
    if (host !== undefined) {
      try {
        const win: window.Window = await window.getLastWindow(host);
        win.setWindowKeepScreenOn(Prefs.bool(PrefKeys.keepScreen, true));
        AppStorage.setOrCreate('readerSafeTop', WindowFx.safeTop(win));
        AppStorage.setOrCreate('readerSafeBottom', WindowFx.safeBottom(win));
        await WindowFx.enterImmersive(win);
      } catch (error) {
      }
    }
    AppStorage.setOrCreate('readerWebOn', true);
    bumpReaderWeb();
  }

  aboutToDisappear(): void {
    appStore.backHook = null;
    appStore.readerExitHook = null;
    AppStorage.setOrCreate('readerWebOn', false);
    appStore.readerIncognito = false;
    this.releaseImmersive();
    this.releaseKeepScreen();
    if (!ttsService.isPlaying()) {
      setTimeout(() => {
        readingTracker.stop();
        ProgressMarks.flush();
      }, 0);
    }
  }

  private releaseKeepScreen(): void {
    const host: common.Context | undefined = this.getUIContext().getHostContext();
    if (host === undefined) {
      return;
    }
    window.getLastWindow(host).then((win: window.Window) => {
      win.setWindowKeepScreenOn(false);
    }).catch(() => {
    });
  }

  private releaseImmersive(): void {
    const host: common.Context | undefined = this.getUIContext().getHostContext();
    if (host === undefined) {
      return;
    }
    window.getLastWindow(host).then((win: window.Window) => {
      WindowFx.exitImmersive(win);
    }).catch(() => {
    });
  }

  private leave(): void {
    if (this.leaving) {
      return;
    }
    this.leaving = true;
    readerWeb.exec('(function(){var e=window.EbookReader;if(e&&e.flush){e.flush();}})()');
    AppStorage.setOrCreate('readerWebOn', false);
    this.releaseImmersive();
    setTimeout(() => {
      try {
        this.nav.pop();
      } catch (error) {
        this.leaving = false;
      }
    }, 16);
  }

  private onBackPressed(): boolean {
    if (!this.busy) {
      readerWeb.exec('(function(){var e=window.EbookReader;if(e&&e.flush){e.flush();}})()');
      AppStorage.setOrCreate('readerWebOn', false);
      this.releaseImmersive();
      return false;
    }
    readerWeb.exec('(function(){var e=window.EbookReader;if(e&&e.back){e.back();}})()');
    return true;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.failed.length > 0) {
        Column() {
          Text(this.failed)
            .fontSize(12)
            .fontColor(C.bad)
          Text(t('返回'))
            .fontSize(12)
            .fontColor(C.acc)
            .margin({ top: 14 })
            .onClick(() => {
              this.leave();
            })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
