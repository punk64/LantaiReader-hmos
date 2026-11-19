import { Prefs } from './Prefs';
import { J } from '../common/Json';

const KEY_PROFILES: string = 'servers';
const KEY_ACTIVE: string = 'activeServer';
const KEY_OWNER: string = 'offlineOwner';
const DEFAULT_KEY: string = 'sk-default';

export interface ServerProfile {
  key: string;
  origin: string;
  cookie: string;
  account: string;
  alias: string;
  fingerprint: string;
  at: number;
  lanPort: number;
  lanAuto: boolean;
  lanHost: string;
  lanScheme: string;
}

export class ServerProfiles {
  private static items: ServerProfile[] = [];
  private static active: string = '';
  private static loaded: boolean = false;

  static load(): void {
    if (ServerProfiles.loaded) {
      return;
    }
    ServerProfiles.loaded = true;
    ServerProfiles.items = ServerProfiles.decode(Prefs.read(KEY_PROFILES));
    ServerProfiles.active = Prefs.read(KEY_ACTIVE);
    if (ServerProfiles.items.length === 0) {
      const origin: string = Prefs.server();
      const cookie: string = Prefs.cookie();
      if (origin.length > 0 && cookie.length > 0) {
        const key: string = ServerProfiles.makeKey();
        ServerProfiles.items.push({
          key: key,
          origin: origin,
          cookie: cookie,
          account: Prefs.account(),
          alias: ServerProfiles.labelOf(origin, Prefs.account()),
          fingerprint: '',
          at: Date.now(),
          lanPort: 25600,
          lanAuto: true,
          lanHost: '',
          lanScheme: 'http'
        });
        ServerProfiles.active = key;
        ServerProfiles.persist();
      }
    }
    if (ServerProfiles.active.length === 0 && ServerProfiles.items.length > 0) {
      ServerProfiles.active = ServerProfiles.items[0].key;
    }
    if (Prefs.read(KEY_OWNER).length === 0) {
      const key: string = ServerProfiles.activeKey();
      Prefs.write(KEY_OWNER, key);
    }
    AppStorage.setOrCreate('serverCount', ServerProfiles.items.length);
  }

  static list(): ServerProfile[] {
    return ServerProfiles.items.slice();
  }

  static count(): number {
    return ServerProfiles.items.length;
  }

  static find(key: string): ServerProfile | null {
    for (let index: number = 0; index < ServerProfiles.items.length; index++) {
      if (ServerProfiles.items[index].key === key) {
        return ServerProfiles.items[index];
      }
    }
    return null;
  }

  static findByOrigin(origin: string): ServerProfile | null {
    for (let index: number = 0; index < ServerProfiles.items.length; index++) {
      if (ServerProfiles.items[index].origin === origin) {
        return ServerProfiles.items[index];
      }
    }
    return null;
  }

  static match(fingerprint: string, account: string): ServerProfile | null {
    if (fingerprint.length === 0 || account.length === 0) {
      return null;
    }
    for (let index: number = 0; index < ServerProfiles.items.length; index++) {
      const item: ServerProfile = ServerProfiles.items[index];
      if (item.fingerprint === fingerprint && item.account === account) {
        return item;
      }
    }
    return null;
  }

  static current(): ServerProfile | null {
    return ServerProfiles.find(ServerProfiles.active);
  }

  static activeKey(): string {
    return ServerProfiles.active.length > 0 ? ServerProfiles.active : DEFAULT_KEY;
  }

  static isActive(key: string): boolean {
    return ServerProfiles.active === key;
  }

  static setActive(key: string): void {
    ServerProfiles.active = key;
  }

  static upsert(profile: ServerProfile): void {
    for (let index: number = 0; index < ServerProfiles.items.length; index++) {
      if (ServerProfiles.items[index].key === profile.key) {
        ServerProfiles.items[index] = profile;
        return;
      }
    }
    ServerProfiles.items.push(profile);
  }

  static remove(key: string): void {
    const kept: ServerProfile[] = [];
    for (let index: number = 0; index < ServerProfiles.items.length; index++) {
      if (ServerProfiles.items[index].key !== key) {
        kept.push(ServerProfiles.items[index]);
      }
    }
    ServerProfiles.items = kept;
    if (ServerProfiles.active === key) {
      ServerProfiles.active = kept.length > 0 ? kept[0].key : '';
    }
  }

  static makeKey(): string {
    const stamp: string = Date.now().toString(36);
    const noise: string = Math.floor(Math.random() * 1679616).toString(36);
    return `sk-${stamp}${noise}`;
  }

  static labelOf(origin: string, account: string): string {
    const host: string = origin.replace('http://', '').replace('https://', '');
    return account.length > 0 ? `${host} · ${account}` : host;
  }

  static ownerKey(): string {
    return Prefs.read(KEY_OWNER);
  }

  static async persistOwner(key: string): Promise<void> {
    await Prefs.write(KEY_OWNER, key);
  }

  static async persist(): Promise<void> {
    await Prefs.write(KEY_PROFILES, JSON.stringify(ServerProfiles.items));
    await Prefs.write(KEY_ACTIVE, ServerProfiles.active);
    AppStorage.setOrCreate('serverCount', ServerProfiles.items.length);
  }

  private static decode(raw: string): ServerProfile[] {
    const out: ServerProfile[] = [];
    const rows: Object[] = J.arrayOf(raw);
    for (let index: number = 0; index < rows.length; index++) {
      const row: Record<string, Object> = rows[index] as Record<string, Object>;
      const key: string = J.str(row, 'key');
      if (key.length === 0) {
        continue;
      }
      const origin: string = J.str(row, 'origin');
      const lanPort: number = J.num(row, 'lanPort');
      const autoRaw: Object = row['lanAuto'];
      out.push({
        key: key,
        origin: origin,
        cookie: J.str(row, 'cookie'),
        account: J.str(row, 'account'),
        alias: J.str(row, 'alias').length > 0 ? J.str(row, 'alias') : ServerProfiles.labelOf(origin, J.str(row, 'account')),
        fingerprint: J.str(row, 'fingerprint'),
        at: J.num(row, 'at'),
        lanPort: lanPort > 0 ? lanPort : 25600,
        lanAuto: typeof autoRaw === 'boolean' ? autoRaw as boolean : true,
        lanHost: J.str(row, 'lanHost'),
        lanScheme: J.str(row, 'lanScheme') === 'https' ? 'https' : 'http'
      });
    }
    return out;
  }
}
