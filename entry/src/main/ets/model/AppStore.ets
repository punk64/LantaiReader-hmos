import { image } from '@kit.ImageKit';
import { LantaiSession } from '../net/LantaiSession';
import { LantaiApi } from '../net/LantaiApi';
import { BookItem, HomePayload, UserProfile } from './LantaiModels';
import { LanScan } from '../net/LanScan';
import { Prefs } from './Prefs';
import { ServerProfile, ServerProfiles } from './ServerProfile';
import { LocalBook } from '../net/LocalLibrary';
import { LocalMeta } from '../net/LocalMeta';
import { ArchiveBook } from '../net/ComicArchive';
import { offlineDb } from '../data/OfflineDb';
import { offlineCache } from '../net/OfflineCache';

import { t } from '../common/I18n';
export class AppStore {
  session: LantaiSession = new LantaiSession();
  api: LantaiApi;
  account: string = '';
  nickname: string = '';
  avatar: image.PixelMap | undefined = undefined;
  avatarKey: string = '';
  avatarUserId: string = '';
  selected: BookItem | null = null;
  selectedSeriesId: string = '';
  readerBookId: string = '';
  readerTitle: string = '';
  readerChapter: number = 1;
  readerIncognito: boolean = false;
  localBooks: LocalBook[] = [];
  localMetas: LocalMeta[] = [];
  localMissing: string[] = [];
  localRoot: string = '';
  localRootStale: boolean = false;
  librarySource: string = '';
  localArchive: ArchiveBook | null = null;
  localArchivePage: number = 1;
  localArchiveId: string = '';
  backHook: (() => boolean) | null = null;
  readerExitHook: (() => void) | null = null;
  offline: boolean = false;

  constructor() {
    this.api = new LantaiApi(this.session);
  }

  async restore(): Promise<boolean> {
    ServerProfiles.load();
    const profile: ServerProfile | null = ServerProfiles.current();
    if (profile === null || profile.origin.length === 0 || profile.cookie.length === 0) {
      return false;
    }
    this.session.restore(profile.origin, profile.cookie);
    this.account = profile.account;
    try {
      const who: string = await this.api.me();
      if (who.length === 0) {
        this.session.reset();
        return false;
      }
      if (this.account.length === 0) {
        this.account = who;
      }
      this.loadProfile();
      return true;
    } catch (error) {
      this.session.reset();
      return false;
    }
  }

  async login(server: string, account: string, password: string): Promise<void> {
    await this.session.login(server, account, password);
    let who: string = '';
    try {
      who = await this.api.me();
    } catch (error) {
      who = '';
    }
    if (who.length === 0) {
      who = account;
    }
    this.account = who;
    const origin: string = this.session.serverOrigin();
    const cookie: string = this.session.cookieHeader();
    const fingerprint: string = await this.fingerprint();
    const merged: ServerProfile | null = ServerProfiles.match(fingerprint, who);
    let key: string = '';
    if (merged !== null) {
      key = merged.key;
    } else {
      const sameOrigin: ServerProfile | null = ServerProfiles.findByOrigin(origin);
      key = sameOrigin !== null ? sameOrigin.key : ServerProfiles.makeKey();
    }
    const existed: ServerProfile | null = ServerProfiles.find(key);
    const pendingAlias: string = Prefs.read('pendingAlias');
    const pendingPort: number = Prefs.int('pendingLanPort', 0);
    const pendingAuto: string = Prefs.read('pendingLanAuto');
    const pendingHost: string = Prefs.read('pendingLanHost');
    const pendingScheme: string = Prefs.read('pendingLanScheme');
    let alias: string = ServerProfiles.labelOf(origin, who);
    if (existed !== null && existed.alias.length > 0) {
      alias = existed.alias;
    } else if (pendingAlias.length > 0) {
      alias = pendingAlias;
    }
    ServerProfiles.upsert({
      key: key,
      origin: origin,
      cookie: cookie,
      account: who,
      alias: alias,
      fingerprint: fingerprint,
      at: Date.now(),
      lanPort: pendingPort > 0 ? pendingPort : (existed !== null && existed.lanPort > 0 ? existed.lanPort : 25600),
      lanAuto: pendingAuto.length > 0 ? pendingAuto === 'true' : (existed !== null ? existed.lanAuto : true),
      lanHost: pendingHost.length > 0 ? pendingHost : (existed !== null ? existed.lanHost : ''),
      lanScheme: pendingScheme.length > 0 ? pendingScheme : (existed !== null ? existed.lanScheme : 'http')
    });
    ServerProfiles.setActive(key);
    await ServerProfiles.persist();
    if (ServerProfiles.ownerKey().length === 0) {
      await ServerProfiles.persistOwner(key);
    }
    offlineDb.setServer(ServerProfiles.activeKey());
    offlineCache.setServer(ServerProfiles.activeKey());
    await Prefs.saveSession(origin, cookie, who);
    if (pendingAlias.length > 0) {
      await Prefs.write('pendingAlias', '');
    }
    if (pendingHost.length > 0) {
      await Prefs.write('pendingLanHost', '');
    }
    if (pendingScheme.length > 0) {
      await Prefs.write('pendingLanScheme', '');
    }
    if (pendingAuto.length > 0) {
      await Prefs.write('pendingLanAuto', '');
    }
    if (pendingPort > 0) {
      await Prefs.write('pendingLanPort', '');
    }
    this.loadProfile();
  }

  async switchTo(key: string): Promise<void> {
    const target: ServerProfile | null = ServerProfiles.find(key);
    if (target === null) {
      throw new Error(t('服务器档案不存在'));
    }
    if (ServerProfiles.isActive(key)) {
      return;
    }
    const previous: ServerProfile | null = ServerProfiles.current();
    this.session.restore(target.origin, target.cookie);
    let valid: boolean = false;
    try {
      valid = (await this.api.me()).length > 0;
    } catch (error) {
      valid = false;
    }
    if (!valid) {
      if (previous !== null) {
        this.session.restore(previous.origin, previous.cookie);
        this.account = previous.account;
      } else {
        this.session.reset();
        this.account = '';
      }
      throw new Error(t('该服务器会话已失效，请重新登录'));
    }
    this.account = target.account;
    this.selected = null;
    ServerProfiles.upsert({
      key: target.key,
      origin: target.origin,
      cookie: target.cookie,
      account: target.account,
      alias: target.alias,
      fingerprint: target.fingerprint,
      at: Date.now(),
      lanPort: target.lanPort,
      lanAuto: target.lanAuto,
      lanHost: target.lanHost,
      lanScheme: target.lanScheme
    });
    ServerProfiles.setActive(key);
    await ServerProfiles.persist();
    await ServerProfiles.persistOwner(key);
    offlineDb.setServer(ServerProfiles.activeKey());
    offlineCache.setServer(ServerProfiles.activeKey());
    await Prefs.saveSession(target.origin, target.cookie, target.account);
    this.loadProfile();
  }

  async rename(key: string, alias: string): Promise<void> {
    const target: ServerProfile | null = ServerProfiles.find(key);
    if (target === null) {
      return;
    }
    ServerProfiles.upsert({
      key: target.key,
      origin: target.origin,
      cookie: target.cookie,
      account: target.account,
      alias: alias,
      fingerprint: target.fingerprint,
      at: target.at,
      lanPort: target.lanPort,
      lanAuto: target.lanAuto,
      lanHost: target.lanHost,
      lanScheme: target.lanScheme
    });
    await ServerProfiles.persist();
  }

  async editProfile(key: string, alias: string, origin: string, lanPort: number,
    lanAuto: boolean, lanHost: string, lanScheme: string): Promise<void> {
    const target: ServerProfile | null = ServerProfiles.find(key);
    if (target === null) {
      return;
    }
    const changed: boolean = origin !== target.origin;
    ServerProfiles.upsert({
      key: target.key,
      origin: origin,
      cookie: target.cookie,
      account: target.account,
      alias: alias,
      fingerprint: target.fingerprint,
      at: target.at,
      lanPort: lanPort,
      lanAuto: lanAuto,
      lanHost: lanHost,
      lanScheme: lanScheme
    });
    await ServerProfiles.persist();
    if (ServerProfiles.isActive(key) && changed) {
      this.session.restore(origin, target.cookie);
      await Prefs.saveSession(origin, target.cookie, target.account);
    }
  }

  async removeProfile(key: string): Promise<boolean> {
    if (ServerProfiles.isActive(key)) {
      return false;
    }
    ServerProfiles.remove(key);
    await ServerProfiles.persist();
    return true;
  }

  async fingerprint(): Promise<string> {
    try {
      const home: HomePayload = await this.api.home(1);
      const ids: string[] = [];
      for (let index: number = 0; index < home.libraries.length; index++) {
        ids.push(home.libraries[index].id);
      }
      ids.sort();
      return ids.join(',');
    } catch (error) {
      return '';
    }
  }

  async logout(): Promise<void> {
    this.session.reset();
    this.selected = null;
    const profile: ServerProfile | null = ServerProfiles.current();
    if (profile !== null) {
      ServerProfiles.upsert({
        key: profile.key,
        origin: profile.origin,
        cookie: '',
        account: profile.account,
        alias: profile.alias,
        fingerprint: profile.fingerprint,
        at: profile.at,
        lanPort: profile.lanPort,
        lanAuto: profile.lanAuto,
        lanHost: profile.lanHost,
        lanScheme: profile.lanScheme
      });
      await ServerProfiles.persist();
    }
    await Prefs.clearCookie();
    this.clearProfile();
  }

  serverLabel(): string {
    const origin: string = this.session.serverOrigin();
    if (origin.length === 0) {
      return t('未连接');
    }
    return origin.replace('http://', '').replace('https://', '');
  }

  enterOffline(): void {
    this.offline = true;
    this.session.reset();
    this.selected = null;
    this.clearProfile();
    AppStorage.setOrCreate('offlineTick', Date.now());
  }

  async exitOffline(): Promise<boolean> {
    const restored: boolean = await this.restore();
    if (!restored) {
      return false;
    }
    this.offline = false;
    return true;
  }

  notifyOffline(): void {
    AppStorage.setOrCreate('offlineTick', Date.now());
  }

  isLanActive(): boolean {
    return LanScan.isPrivate(this.session.serverOrigin());
  }

  connectionLabel(): string {
    if (this.offline) {
      return t('离线模式');
    }
    if (this.session.serverOrigin().length === 0) {
      return t('未连接');
    }
    return `${this.isLanActive() ? t('局域网') : t('公网')} · ${this.serverLabel()}`;
  }

  displayName(): string {
    if (this.nickname.length > 0) {
      return this.nickname;
    }
    if (this.account.length > 0) {
      return this.account;
    }
    return t('本机读者');
  }

  async loadProfile(): Promise<void> {
    let profile: UserProfile;
    try {
      profile = await this.api.userProfile();
    } catch (error) {
      return;
    }
    const name: string = profile.nickname.length > 0 ? profile.nickname : profile.username;
    if (name.length > 0) {
      this.nickname = name;
    }
    const key: string = `${profile.userId}|${profile.avatarUpdated}|${profile.hasAvatar}`;
    if (key !== this.avatarKey) {
      this.avatarKey = key;
      this.avatarUserId = profile.userId;
      this.avatar = undefined;
      if (profile.hasAvatar && profile.userId.length > 0) {
        let source: image.ImageSource | undefined = undefined;
        try {
          const bytes: ArrayBuffer = await this.api.userAvatar(profile.userId);
          source = image.createImageSource(bytes);
          const options: image.DecodingOptions = { editable: false };
          const pixel: image.PixelMap | undefined = await source.createPixelMap(options);
          if (pixel !== undefined) {
            this.avatar = pixel;
          }
        } catch (error) {
        } finally {
          if (source !== undefined) {
            source.release();
          }
        }
      }
    }
    AppStorage.setOrCreate('profileTick', Date.now());
  }

  clearProfile(): void {
    this.nickname = '';
    this.avatar = undefined;
    this.avatarKey = '';
    this.avatarUserId = '';
    AppStorage.setOrCreate('profileTick', Date.now());
  }
}

export const appStore: AppStore = new AppStore();
