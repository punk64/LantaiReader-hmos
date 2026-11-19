import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { C } from '../common/Theme';
import { AppCtx } from '../common/AppCtx';
import { appStore } from '../model/AppStore';
import { ProgressMarks } from '../common/ProgressMarks';
import { BookItem } from '../model/LantaiModels';
import { ENTRY_FILE, ResourceProxy, VIRTUAL_ORIGIN } from '../net/ResourceProxy';
import { NativeBridge } from '../net/NativeBridge';
import { ttsService } from '../net/TtsService';
import { t } from '../common/I18n';

const TAG: string = 'LantaiReader';

export class ReaderWeb {
  controller: webview.WebviewController = new webview.WebviewController();
  private proxy: ResourceProxy | null = null;
  private bridge: NativeBridge | null = null;
  private assets: Map<string, ArrayBuffer> = new Map<string, ArrayBuffer>();
  private attached: boolean = false;
  private pending: boolean = false;
  private expect: boolean = false;
  safeTop: number = 0;
  safeBottom: number = 0;
  loaded: boolean = false;
  bookId: string = '';

  private readRaw(name: string): ArrayBuffer {
    const hit: ArrayBuffer | undefined = this.assets.get(name);
    if (hit !== undefined) {
      return hit;
    }
    const host: common.UIAbilityContext | null = AppCtx.get();
    if (host === null) {
      return new ArrayBuffer(0);
    }
    try {
      const bytes: Uint8Array = host.resourceManager.getRawFileContentSync(name);
      const buffer: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
      this.assets.set(name, buffer);
      return buffer;
    } catch (error) {
      return new ArrayBuffer(0);
    }
  }

  exec(js: string): void {
    if (!this.loaded) {
      return;
    }
    try {
      this.controller.runJavaScript(js);
    } catch (error) {
      hilog.warn(0x0000, TAG, 'web exec failed');
    }
  }

  push(json: string): void {
    this.exec(`(function(){var e=window.EbookReader;if(e&&e.ttsSync){e.ttsSync(${JSON.stringify(json)});}})()`);
  }

  attach(): void {
    if (this.attached) {
      return;
    }
    this.attached = true;
    try {
      const handler = new webview.WebSchemeHandler();
      handler.onRequestStart((request: webview.WebSchemeHandlerRequest,
        resource: webview.WebResourceHandler): boolean => {
        return this.proxyOf().handle(request, resource);
      });
      handler.onRequestStop((request: webview.WebSchemeHandlerRequest): void => {
      });
      this.controller.setWebSchemeHandler('https', handler);
      this.controller.registerJavaScriptProxy(this.bridgeOf(), 'lantaiBridge',
        ['report', 'post', 'exit', 'ttsStart', 'ttsSeek', 'ttsPause', 'ttsResume', 'ttsStop', 'ttsOnce',
          'ttsVoices', 'ttsTone', 'ttsToneNow', 'ttsLoadVoices']);
      this.controller.refresh();
      ttsService.setNotify((json: string) => {
        this.push(json);
      });
    } catch (error) {
      hilog.error(0x0000, TAG, 'scheme handler failed %{public}s', (error as Error).message);
    }
  }

  private proxyOf(): ResourceProxy {
    if (this.proxy === null) {
      this.proxy = new ResourceProxy(appStore.session, (name: string) => this.readRaw(name),
        () => appStore.readerIncognito,
        (path: string) => ReaderWeb.noteProgress(path));
    }
    return this.proxy;
  }

  private bridgeOf(): NativeBridge {
    if (this.bridge === null) {
      this.bridge = new NativeBridge(appStore.session,
        (json: string) => {
          ReaderWeb.noteUi(json);
        },
        (method: string, path: string, ok: boolean, status: number) => {
          if (!ok) {
            hilog.warn(0x0000, TAG, 'post %{public}s %{public}s -> %{public}d', method, path, status);
          }
          ReaderWeb.noteProgress(path);
        },
        () => {
          const hook: (() => void) | null = appStore.readerExitHook;
          if (hook !== null) {
            hook();
          }
        },
        false);
    }
    return this.bridge;
  }

  private static noteUi(json: string): void {
    if (json.indexOf('"ui"') < 0) {
      hilog.info(0x0000, TAG, 'page %{public}s', json);
      return;
    }
    const open: boolean = json.indexOf('"open":true') >= 0;
    const idle: boolean = json.indexOf('"idle":true') >= 0;
    const panel: boolean = json.indexOf('"panel":"') >= 0 && json.indexOf('"panel":""') < 0;
    const busy: boolean = open && (panel || json.indexOf('"sel":true') >= 0 || json.indexOf('"lb":true') >= 0 ||
      json.indexOf('"ask":true') >= 0 || json.indexOf('"guide":true') >= 0 || !idle);
    AppStorage.setOrCreate('readerBusy', busy);
  }

  private static noteProgress(path: string): void {
    if (appStore.readerIncognito || path.indexOf('/read-progress') < 0) {
      return;
    }
    const book: string = ReaderWeb.param(path, 'book');
    if (book.length === 0) {
      return;
    }
    const tp: number = parseFloat(ReaderWeb.param(path, 'tp'));
    if (!(tp > 0)) {
      return;
    }
    const id: string = decodeURIComponent(book);
    const selected: BookItem | null = appStore.selected;
    const hit: boolean = selected !== null && selected.id === id;
    const pages: number = hit && selected !== null ? selected.pages : 0;
    if (pages <= 0) {
      return;
    }
    const done: boolean = hit && selected !== null ? selected.readCompleted : false;
    const page: number = Math.max(1, Math.min(pages, Math.round(tp * pages)));
    ProgressMarks.put(id, page, pages, done);
  }

  private static param(path: string, key: string): string {
    const at: number = path.indexOf(`${key}=`);
    if (at < 0) {
      return '';
    }
    let rest: string = path.substring(at + key.length + 1);
    const amp: number = rest.indexOf('&');
    if (amp >= 0) {
      rest = rest.substring(0, amp);
    }
    return rest;
  }

  open(bookId: string): void {
    const same: boolean = this.loaded && this.bookId === bookId;
    this.bookId = bookId;
    if (!this.attached) {
      this.pending = true;
      return;
    }
    if (same) {
      return;
    }
    this.load(bookId);
  }

  resume(): void {
    if (!this.pending) {
      return;
    }
    this.pending = false;
    this.load(this.bookId);
  }

  markLoaded(): void {
    if (this.expect) {
      this.expect = false;
      this.loaded = true;
    }
  }

  private load(bookId: string): void {
    if (bookId.length === 0) {
      return;
    }
    const target: string = `${VIRTUAL_ORIGIN}/${ENTRY_FILE}?book=${bookId}`;
    setTimeout(() => {
      const st: number = Math.round(this.safeTop);
      const sb: number = Math.round(this.safeBottom);
      try {
        this.expect = true;
        this.controller.loadUrl(`${target}&st=${st}&sb=${sb}&r=${Date.now()}`);
      } catch (error) {
        this.expect = false;
        hilog.error(0x0000, TAG, 'load url failed %{public}s', (error as Error).message);
      }
    }, 0);
  }
}

export const readerWeb: ReaderWeb = new ReaderWeb();

let webTick: number = 0;

export function bumpReaderWeb(): void {
  webTick += 1;
  AppStorage.setOrCreate('readerWebTick', webTick);
}

@Component
export struct ReadingWeb {
  @StorageLink('readerWebOn') @Watch('onVis') on: boolean = false;
  @StorageLink('readerWebTick') @Watch('onTick') tick: number = 0;
  @StorageProp('readerSafeTop') safeTop: number = 0;
  @StorageProp('readerSafeBottom') safeBottom: number = 0;
  @State live: boolean = false;
  @State failed: string = '';
  @State stalled: boolean = false;
  @State ready: boolean = false;
  private watchdog: number = -1;

  aboutToAppear(): void {
    ttsService.setNotify((json: string) => {
      readerWeb.push(json);
    });
  }

  aboutToDisappear(): void {
    this.disarm();
  }

  private onVis(): void {
    try {
      if (this.on) {
        readerWeb.controller.onActive();
      } else if (!ttsService.isPlaying()) {
        readerWeb.controller.onInactive();
      }
    } catch (error) {
    }
  }

  private onTick(): void {
    if (this.tick <= 0) {
      return;
    }
    this.live = true;
    const id: string = appStore.readerBookId;
    if (id.length === 0) {
      return;
    }
    this.failed = '';
    this.stalled = false;
    this.ready = readerWeb.loaded;
    try {
      readerWeb.controller.onActive();
    } catch (error) {
    }
    readerWeb.safeTop = this.safeTop;
    readerWeb.safeBottom = this.safeBottom;
    readerWeb.open(id);
    this.arm();
  }

  private arm(): void {
    this.disarm();
    this.watchdog = setTimeout(() => {
      this.watchdog = -1;
      this.probe();
    }, 20000);
  }

  private disarm(): void {
    if (this.watchdog < 0) {
      return;
    }
    clearTimeout(this.watchdog);
    this.watchdog = -1;
  }

  private probe(): void {
    try {
      readerWeb.controller.runJavaScript(
        '(function(){try{var e=window.EbookReader;if(!e||!e.isOpen()||!e.current)return "0";var c=e.current();return c&&c.bootDone?"1":"0"}catch(x){return "0"}})()')
        .then((value: string) => {
          this.stalled = String(value).indexOf('1') < 0;
        })
        .catch(() => {
          this.stalled = true;
        });
    } catch (error) {
      this.stalled = true;
    }
  }

  private retry(): void {
    this.failed = '';
    this.stalled = false;
    readerWeb.open(appStore.readerBookId);
    this.arm();
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.live) {
        Web({ src: 'about:blank', controller: readerWeb.controller })
          .onControllerAttached(() => {
            readerWeb.attach();
            readerWeb.resume();
          })
          .onPageEnd(() => {
            readerWeb.markLoaded();
            this.disarm();
            this.stalled = false;
            this.ready = true;
          })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .mixedMode(MixedMode.All)
          .fileAccess(false)
          .imageAccess(true)
          .onlineImageAccess(true)
          .databaseAccess(false)
          .onContextMenuShow((event: OnContextMenuShowEvent): boolean => {
            return true;
          })
          .editMenuOptions({
            onCreateMenu: (items: Array<TextMenuItem>): Array<TextMenuItem> => {
              return [];
            },
            onMenuItemClick: (item: TextMenuItem, range: TextRange): boolean => {
              return true;
            }
          })
          .width('100%')
          .height('100%')
          .hitTestBehavior(this.on ? HitTestMode.Default : HitTestMode.None)

        if (!this.ready) {
          Row({ space: 7 }) {
            LoadingProgress().width(14).height(14).color(C.acc)
            Text(t('载入中'))
              .fontSize(10.5)
              .fontColor(C.tx3)
          }
          .padding({ left: 11, right: 13, top: 6, bottom: 6 })
          .backgroundColor(C.glassDeep)
          .borderRadius(99)
          .border({ width: 1, color: C.line })
          .margin({ left: 12, top: 54 })
          .hitTestBehavior(HitTestMode.None)
        }

        if (this.stalled) {
          Column() {
            Text(t('服务端没有响应'))
              .fontSize(12)
              .fontColor(C.bad)
              .textAlign(TextAlign.Center)
            Text(t('内容加载超时，可重试一次'))
              .fontSize(11)
              .fontColor(C.tx3)
              .margin({ top: 6 })
            Row({ space: 20 }) {
              Text(t('重试'))
                .fontSize(12)
                .fontColor(C.acc)
                .onClick(() => {
                  this.retry();
                })
              Text(t('返回'))
                .fontSize(12)
                .fontColor(C.tx3)
                .onClick(() => {
                  const hook: (() => void) | null = appStore.readerExitHook;
                  if (hook !== null) {
                    hook();
                  }
                })
            }
            .margin({ top: 14 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(C.bg)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
    .opacity(this.on ? 1 : 0)
    .animation({ duration: 120, curve: Curve.EaseOut })
    .hitTestBehavior(this.on ? HitTestMode.Default : HitTestMode.None)
  }
}
