import { connection } from '@kit.NetworkKit';
import { appStore } from '../model/AppStore';
import { Prefs } from '../model/Prefs';
import { ServerProfile, ServerProfiles } from '../model/ServerProfile';
import { LanHit, LanScan } from './LanScan';

import { t, tf } from '../common/I18n';
const KEY_NOTE: string = 'autoSwitchNote';
const SCAN_GAP: number = 60000;
const DEFAULT_PORT: number = 25600;

export class AutoSwitch {
  private static watching: boolean = false;
  private static busy: boolean = false;
  private static lastScan: number = 0;

  static lanOriginOf(profile: ServerProfile): string {
    if (profile.lanHost.length === 0 || profile.lanPort <= 0) {
      return '';
    }
    return LanScan.originOf(profile.lanScheme, profile.lanHost, profile.lanPort);
  }

  static note(): string {
    const raw: string = Prefs.read(KEY_NOTE);
    if (raw.length === 0) {
      return '';
    }
    const parts: string[] = raw.split('|');
    if (parts.length < 2) {
      return '';
    }
    const at: number = parseInt(parts[1], 10);
    if (isNaN(at) || at <= 0) {
      return parts[0];
    }
    const minutes: number = Math.floor((Date.now() - at) / 60000);
    const ago: string = minutes < 1 ? t('刚刚') : minutes < 60 ? t(`${minutes} 分钟前`) : t(`${Math.floor(minutes / 60)} 小时前`);
    return `${parts[0]} · ${ago}`;
  }

  static start(): void {
    if (!AutoSwitch.watching) {
      AutoSwitch.watching = true;
      try {
        const conn: connection.NetConnection = connection.createNetConnection();
        conn.on('netAvailable', () => {
          AutoSwitch.check();
        });
        conn.on('netLost', () => {
          AutoSwitch.check();
        });
        conn.on('netCapabilitiesChange', () => {
          AutoSwitch.check();
        });
        conn.register(() => {
        });
      } catch (error) {
      }
    }
    AutoSwitch.check();
  }

  static async check(): Promise<void> {
    if (AutoSwitch.busy) {
      return;
    }
    const profile: ServerProfile | null = ServerProfiles.current();
    if (profile === null || profile.cookie.length === 0) {
      return;
    }
    const lan: string = AutoSwitch.lanOriginOf(profile);
    if (lan.length === 0 && !profile.lanAuto) {
      return;
    }
    AutoSwitch.busy = true;
    try {
      await AutoSwitch.run(profile, lan);
    } catch (error) {
    }
    AutoSwitch.busy = false;
    AutoSwitch.notify();
  }

  private static async run(profile: ServerProfile, lan: string): Promise<void> {
    const current: string = appStore.session.serverOrigin();
    if (!await AutoSwitch.onLan()) {
      if (current !== profile.origin) {
        appStore.session.setOrigin(profile.origin);
        AutoSwitch.mark(t('已切回公网'));
      }
      return;
    }
    if (lan.length > 0 && await LanScan.ping(lan, profile.cookie)) {
      if (current !== lan) {
        appStore.session.setOrigin(lan);
        AutoSwitch.mark(tf('已连接局域网 {0}', [profile.lanHost]));
      }
      return;
    }
    if (lan.length > 0 && current === lan) {
      appStore.session.setOrigin(profile.origin);
      AutoSwitch.mark(t('局域网不可达，已切回公网'));
    }
    if (!profile.lanAuto) {
      return;
    }
    const now: number = Date.now();
    if (now - AutoSwitch.lastScan < SCAN_GAP) {
      return;
    }
    AutoSwitch.lastScan = now;
    const hit: LanHit | null = await AutoSwitch.discover(profile);
    if (hit === null) {
      if (current !== profile.origin) {
        appStore.session.setOrigin(profile.origin);
        AutoSwitch.mark(t('局域网未发现，已切回公网'));
      }
      return;
    }
    appStore.session.setOrigin(hit.origin);
    AutoSwitch.mark(tf('已发现局域网 {0}', [hit.host]));
    await AutoSwitch.remember(profile, hit);
  }

  private static async discover(profile: ServerProfile): Promise<LanHit | null> {
    const ports: number[] = [];
    if (profile.lanPort > 0) {
      ports.push(profile.lanPort);
    }
    const mainPort: number = AutoSwitch.portOf(profile.origin);
    if (mainPort > 0 && ports.indexOf(mainPort) < 0) {
      ports.push(mainPort);
    }
    if (ports.indexOf(DEFAULT_PORT) < 0) {
      ports.push(DEFAULT_PORT);
    }
    const schemes: string[] = [profile.lanScheme];
    schemes.push(profile.lanScheme === 'https' ? 'http' : 'https');
    const hits: LanHit[] = await LanScan.scan(ports, schemes);
    if (hits.length === 0) {
      return null;
    }
    for (let index: number = 0; index < hits.length; index++) {
      if (await LanScan.ping(hits[index].origin, profile.cookie)) {
        return hits[index];
      }
    }
    return null;
  }

  private static async remember(profile: ServerProfile, hit: LanHit): Promise<void> {
    if (profile.lanHost === hit.host && profile.lanPort === hit.port && profile.lanScheme === hit.scheme) {
      return;
    }
    ServerProfiles.upsert({
      key: profile.key,
      origin: profile.origin,
      cookie: profile.cookie,
      account: profile.account,
      alias: profile.alias,
      fingerprint: profile.fingerprint,
      at: profile.at,
      lanPort: hit.port,
      lanAuto: profile.lanAuto,
      lanHost: hit.host,
      lanScheme: hit.scheme
    });
    await ServerProfiles.persist();
  }

  private static mark(text: string): void {
    Prefs.write(KEY_NOTE, `${text}|${Date.now()}`);
    AutoSwitch.notify();
  }

  static notify(): void {
    AppStorage.setOrCreate('netTick', Date.now());
  }

  private static async onLan(): Promise<boolean> {
    try {
      const net: connection.NetHandle = await connection.getDefaultNet();
      const caps: connection.NetCapabilities = await connection.getNetCapabilities(net);
      const types: connection.NetBearType[] = caps.bearerTypes;
      for (let index: number = 0; index < types.length; index++) {
        if (types[index] === connection.NetBearType.BEARER_WIFI ||
          types[index] === connection.NetBearType.BEARER_ETHERNET) {
          return true;
        }
      }
    } catch (error) {
    }
    return false;
  }

  private static portOf(origin: string): number {
    const body: string = origin.replace('http://', '').replace('https://', '');
    const colon: number = body.indexOf(':');
    if (colon <= 0) {
      return 0;
    }
    const value: number = parseInt(body.substring(colon + 1), 10);
    return isNaN(value) ? 0 : value;
  }
}
