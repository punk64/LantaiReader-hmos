import { common } from '@kit.AbilityKit';
import { C } from '../common/Theme';
import { appStore } from '../model/AppStore';
import { SeriesPage } from '../model/LantaiModels';
import { Prefs, PrefKeys } from '../model/Prefs';
import { Lang } from '../common/I18n';
import { ServerProfiles } from '../model/ServerProfile';
import { CoverCache } from '../components/CoverCache';
import { offlineDb } from '../data/OfflineDb';
import { offlineCache } from '../net/OfflineCache';
import { downloader } from '../net/OfflineDownloader';
import { progressOutbox } from '../net/ProgressOutbox';
import { readingTracker } from '../net/ReadingSession';
import { comicArchive } from '../net/ComicArchive';
import { localBookSource } from '../net/LocalBookSource';
import { localMetas } from '../net/LocalMeta';
import { CachePurge } from '../net/CachePurge';
import { SeriesCache } from '../net/SeriesCache';
import { AutoSwitch } from '../net/AutoSwitch';
import { LocalRestore, LocalStore } from '../net/LocalStore';
import { AnnotationsPage } from './AnnotationsPage';
import { BookDetailPage } from './BookDetailPage';
import { CollectionsPage } from './CollectionsPage';
import { ComicReaderPage } from './ComicReaderPage';
import { DownloadsPage } from './DownloadsPage';
import { ImportPage } from './ImportPage';
import { LibraryPage } from './LibraryPage';
import { LoginPage } from './LoginPage';
import { MainShell } from './MainShell';
import { TtsBar } from '../components/TtsBar';
import { ReadingWeb } from '../components/ReadingWeb';
import { PrefsPage } from './PrefsPage';
import { ReaderPage } from './ReaderPage';
import { ReadlistsPage } from './ReadlistsPage';
import { SeriesDetailPage } from './SeriesDetailPage';
import { ServerPage } from './ServerPage';
import { SourcesPage } from './SourcesPage';

@Entry
@Component
struct Index {
  @StorageLink('uiTick') uiTick: number = 0;
  @Provide('nav') nav: NavPathStack = new NavPathStack();
  @StorageLink('logoutTick') @Watch('onLogoutTick') logoutTick: number = 0;
  @StorageLink('serverTick') @Watch('onServerTick') serverTick: number = 0;
  @StorageLink('offlineTick') @Watch('onOfflineTick') offlineTick: number = 0;
  @StorageLink('loginTick') @Watch('onLoginTick') loginTick: number = 0;
  @State phase: string = 'boot';

  aboutToAppear(): void {
    this.boot();
  }

  onLoginTick(): void {
    this.nav.clear();
    CoverCache.clear();
    SeriesCache.clear();
    appStore.offline = false;
    appStore.session.reset();
    appStore.selected = null;
    appStore.clearProfile();
    AppStorage.setOrCreate('mainTab', 0);
    this.phase = 'login';
  }

  onLogoutTick(): void {
    if (appStore.offline) {
      return;
    }
    if (this.phase === 'home') {
      this.toLogin();
    }
  }

  onOfflineTick(): void {
    this.nav.clear();
    CoverCache.clear();
    SeriesCache.clear();
    appStore.selected = null;
    if (appStore.offline) {
      AppStorage.setOrCreate('mainTab', 1);
    }
    this.phase = 'boot';
    setTimeout(() => {
      this.phase = 'home';
    }, 40);
  }

  onServerTick(): void {
    if (this.phase !== 'home') {
      return;
    }
    this.nav.clear();
    CoverCache.clear();
    SeriesCache.clear();
    appStore.selected = null;
    this.phase = 'boot';
    setTimeout(() => {
      this.phase = 'home';
    }, 40);
  }

  private async boot(): Promise<void> {
    const host: common.Context | undefined = this.getUIContext().getHostContext();
    if (host !== undefined) {
      try {
        await Prefs.init(host);
      } catch (error) {
        this.phase = 'login';
        return;
      }
      ServerProfiles.load();
      C.apply(Prefs.read(PrefKeys.uiTheme));
      Lang.code = Prefs.read(PrefKeys.lang) === Lang.en ? Lang.en : Lang.zh;
      offlineDb.setServer(ServerProfiles.activeKey());
      offlineCache.setServer(ServerProfiles.activeKey());
      try {
        await offlineDb.init(host);
      } catch (error) {
      }
      await readingTracker.init();
      readingTracker.attach(appStore.session);
      offlineCache.init(host);
      comicArchive.init(host);
      localBookSource.init(host);
      localMetas.init(host);
      CachePurge.init(host);
      downloader.attach(appStore.session, host as common.UIAbilityContext);
      await this.restoreLocal();
    }
    const restored: boolean = await appStore.restore();
    this.phase = restored ? 'home' : 'login';
    if (restored) {
      await downloader.reset();
      await progressOutbox.flush(appStore.session);
      await readingTracker.flush(appStore.session);
      AutoSwitch.start();
      this.warmLibrary();
    }
  }

  private warmLibrary(): void {
    setTimeout(() => {
      const key: string = SeriesCache.keyOf(0, 12, 'metadata.titleSort,asc');
      if (SeriesCache.get(key) !== undefined) {
        return;
      }
      appStore.api.seriesPage(0, 12, 'metadata.titleSort,asc')
        .then((page: SeriesPage) => {
          SeriesCache.put(key, page);
        })
        .catch(() => {
        });
    }, 500);
  }

  private async restoreLocal(): Promise<void> {
    try {
      const local: LocalRestore = await LocalStore.restore();
      appStore.localRoot = local.root;
      appStore.localRootStale = local.stale;
      appStore.localBooks = local.books;
      appStore.localMetas = local.metas;
      appStore.localMissing = local.missing;
    } catch (error) {
    }
  }

  private toLogin(): void {
    this.nav.clear();
    CoverCache.clear();
    SeriesCache.clear();
    appStore.logout();
    this.phase = 'login';
  }

  private openReader(): void {
    const names: string[] = this.nav.getAllPathName();
    if (names.length > 0 && names[names.length - 1] === 'reader') {
      return;
    }
    this.nav.pushPathByName('reader', null);
  }

  @Builder
  dest(name: string) {
    NavDestination() {
      if (name === 'library') {
        LibraryPage()
      } else if (name === 'book') {
        BookDetailPage()
      } else if (name === 'reader') {
        ReaderPage()
      } else if (name === 'comic') {
        ComicReaderPage()
      } else if (name === 'series') {
        SeriesDetailPage()
      } else if (name === 'collections') {
        CollectionsPage()
      } else if (name === 'readlists') {
        ReadlistsPage()
      } else if (name === 'annotations') {
        AnnotationsPage()
      } else if (name === 'sources') {
        SourcesPage()
      } else if (name === 'import') {
        ImportPage()
      } else if (name === 'downloads') {
        DownloadsPage()
      } else if (name === 'server') {
        ServerPage()
      } else if (name === 'prefs') {
        PrefsPage()
      }
    }
    .hideTitleBar(true)
    .backgroundColor(C.bg)
    .onBackPressed(() => {
      const hook: (() => boolean) | null = appStore.backHook;
      if (hook === null) {
        return false;
      }
      return hook();
    })
  }

  build() {
    Stack() {
      Navigation(this.nav) {
      if (this.phase === 'home') {
        MainShell({
          onLogout: () => {
            this.toLogin();
          }
        })
      } else if (this.phase === 'login') {
        LoginPage({
          onLogged: () => {
            this.phase = 'home';
            AutoSwitch.start();
          }
        })
      } else {
        Stack() {
          LoadingProgress().width(30).height(30).color(C.acc)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(C.bg)
      }
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.dest)
    .backgroundColor(C.bg)
    .width('100%')
    .height('100%')

      ReadingWeb()

      TtsBar({
        onOpenReader: () => {
          this.openReader();
        }
      })
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart)
  }
}
