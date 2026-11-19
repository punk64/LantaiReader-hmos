import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'lantai_reader';
const KEY_SERVER: string = 'server';
const KEY_COOKIE: string = 'cookie';
const KEY_ACCOUNT: string = 'account';

export class PrefKeys {
  static readonly cmMode: string = 'cmMode';
  static readonly cmFit: string = 'cmFit';
  static readonly cmQuality: string = 'cmQuality';
  static readonly cmMargin: string = 'cmMargin';
  static readonly cmDir: string = 'cmDir';
  static readonly fs: string = 'ebFontSize';
  static readonly lh: string = 'ebLineHeight';
  static readonly measure: string = 'ebMeasure';
  static readonly ebFont: string = 'ebFont';
  static readonly ebTheme: string = 'ebTheme';
  static readonly keepScreen: string = 'keepScreen';
  static readonly hideStatus: string = 'hideStatus';
  static readonly autoHide: string = 'autoHide';
  static readonly prefSync: string = 'prefSync';
  static readonly cacheLimit: string = 'cacheLimit';
  static readonly lang: string = 'uiLang';
  static readonly uiTheme: string = 'uiTheme';
  static readonly repo: string = 'updateRepo';
  static readonly comicGuide: string = 'comicGuideSeen';
  static readonly ebookGuide: string = 'ebookGuideSeen';
  static readonly syncAt: string = 'syncAt';
  static readonly sweepAt: string = 'sweepAt';
  static readonly ttsTone: string = 'ttsTone';
  static readonly ttsSpeed: string = 'ttsSpeed';
  static readonly ttsBarSide: string = 'ttsBarSide';
  static readonly ttsBarYr: string = 'ttsBarYr';
}

export class Prefs {
  private static store: preferences.Preferences | null = null;

  static async init(ctx: common.Context): Promise<void> {
    if (Prefs.store !== null) {
      return;
    }
    Prefs.store = await preferences.getPreferences(ctx, STORE_NAME);
  }

  static server(): string {
    return Prefs.read(KEY_SERVER);
  }

  static cookie(): string {
    return Prefs.read(KEY_COOKIE);
  }

  static account(): string {
    return Prefs.read(KEY_ACCOUNT);
  }

  static read(key: string): string {
    if (Prefs.store === null) {
      return '';
    }
    try {
      const value: preferences.ValueType = Prefs.store.getSync(key, '');
      return typeof value === 'string' ? value as string : '';
    } catch (error) {
      return '';
    }
  }

  static async write(key: string, value: string): Promise<void> {
    if (Prefs.store === null) {
      return;
    }
    await Prefs.store.put(key, value);
    await Prefs.store.flush();
  }

  static async saveSession(server: string, cookie: string, account: string): Promise<void> {
    await Prefs.write(KEY_SERVER, server);
    await Prefs.write(KEY_COOKIE, cookie);
    await Prefs.write(KEY_ACCOUNT, account);
  }

  static async clearCookie(): Promise<void> {
    await Prefs.write(KEY_COOKIE, '');
  }

  static int(key: string, fallback: number): number {
    const raw: string = Prefs.read(key);
    if (raw.length === 0) {
      return fallback;
    }
    const value: number = parseInt(raw, 10);
    return isNaN(value) ? fallback : value;
  }

  static bool(key: string, fallback: boolean): boolean {
    const raw: string = Prefs.read(key);
    if (raw.length === 0) {
      return fallback;
    }
    return raw === 'true';
  }

  static async putInt(key: string, value: number): Promise<void> {
    await Prefs.write(key, `${value}`);
  }

  static async putBool(key: string, value: boolean): Promise<void> {
    await Prefs.write(key, value ? 'true' : 'false');
  }
}
