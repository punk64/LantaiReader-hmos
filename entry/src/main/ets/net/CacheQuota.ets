import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { storageStatistics } from '@kit.CoreFileKit';
import { PrefKeys, Prefs } from '../model/Prefs';

interface CacheEntry {
  path: string;
  used: number;
}

const USED: string = '.used';
const TOUCH_GAP: number = 300000;

export class CacheQuota {
  static readonly fallback: number = 4 * 1024 * 1024 * 1024;
  static readonly lowest: number = 256 * 1024 * 1024;
  static readonly highest: number = 64 * 1024 * 1024 * 1024;
  private static roots: string[] = [];
  private static touched: Map<string, number> = new Map<string, number>();

  static init(ctx: common.Context): void {
    if (CacheQuota.roots.length === 0) {
      CacheQuota.roots = [`${ctx.cacheDir}/archive`, `${ctx.cacheDir}/local`];
    }
  }

  static ready(): boolean {
    return CacheQuota.roots.length > 0;
  }

  static paths(): string[] {
    return CacheQuota.roots.slice();
  }

  static limit(): number {
    const value: number = Prefs.int(PrefKeys.cacheLimit, CacheQuota.fallback);
    if (value < CacheQuota.lowest || value > CacheQuota.highest) {
      return CacheQuota.fallback;
    }
    return value;
  }

  static parse(text: string): number {
    const raw: string = text.trim().toUpperCase().replace(/\s+/g, '');
    if (raw.length === 0) {
      return 0;
    }
    const match: RegExpExecArray | null = /^([0-9]+(?:\.[0-9]+)?)([KMG]?)B?$/.exec(raw);
    if (match === null) {
      return 0;
    }
    const value: number = parseFloat(match[1]);
    if (isNaN(value) || value <= 0) {
      return 0;
    }
    const unit: string = match[2];
    const factor: number = unit === 'K' ? 1024 : unit === 'M' ? 1048576 : 1073741824;
    const bytes: number = Math.round(value * factor);
    if (bytes < CacheQuota.lowest || bytes > CacheQuota.highest) {
      return 0;
    }
    return bytes;
  }

  static async apply(bytes: number): Promise<void> {
    const value: number = bytes < CacheQuota.lowest ? CacheQuota.lowest :
      bytes > CacheQuota.highest ? CacheQuota.highest : bytes;
    await Prefs.putInt(PrefKeys.cacheLimit, value);
    await CacheQuota.enforce();
  }

  static async measure(): Promise<number> {
    const cached: number = await CacheQuota.bundleCache();
    if (cached >= 0) {
      return cached;
    }
    let total: number = 0;
    for (let index: number = 0; index < CacheQuota.roots.length; index++) {
      total += await CacheQuota.sizeOf(CacheQuota.roots[index]);
    }
    return total;
  }

  private static async bundleCache(): Promise<number> {
    try {
      const stats: storageStatistics.BundleStats = await storageStatistics.getCurrentBundleStats();
      return stats.cacheSize;
    } catch (error) {
      return -1;
    }
  }

  static touch(dir: string): void {
    if (dir.length === 0) {
      return;
    }
    const now: number = Date.now();
    const last: number | undefined = CacheQuota.touched.get(dir);
    if (last !== undefined && now - last < TOUCH_GAP) {
      return;
    }
    CacheQuota.touched.set(dir, now);
    try {
      const file: fs.File = fs.openSync(`${dir}/${USED}`,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, `${now}`);
      fs.closeSync(file);
    } catch (error) {
    }
  }

  static async enforce(keep: string = ''): Promise<number> {
    try {
      const limit: number = CacheQuota.limit();
      const total: number = await CacheQuota.measure();
      if (total <= limit) {
        return 0;
      }
      let need: number = total - Math.floor(limit * 0.9);
      if (need <= 0) {
        return 0;
      }
      const entries: CacheEntry[] = [];
      for (let index: number = 0; index < CacheQuota.roots.length; index++) {
        const found: CacheEntry[] = await CacheQuota.entriesOf(CacheQuota.roots[index]);
        for (let at: number = 0; at < found.length; at++) {
          entries.push(found[at]);
        }
      }
      entries.sort((left: CacheEntry, right: CacheEntry) => left.used - right.used);
      let freed: number = 0;
      for (let index: number = 0; index < entries.length && need > 0; index++) {
        const entry: CacheEntry = entries[index];
        if (keep.length > 0 && entry.path === keep) {
          continue;
        }
        const size: number = await CacheQuota.sizeOf(entry.path);
        try {
          await fs.rmdir(entry.path);
        } catch (error) {
          continue;
        }
        CacheQuota.touched.delete(entry.path);
        need -= size;
        freed += size;
      }
      return freed;
    } catch (error) {
      return 0;
    }
  }

  private static async entriesOf(base: string): Promise<CacheEntry[]> {
    const out: CacheEntry[] = [];
    try {
      if (!fs.accessSync(base)) {
        return out;
      }
    } catch (error) {
      return out;
    }
    let names: string[] = [];
    try {
      names = await fs.listFile(base);
    } catch (error) {
      return out;
    }
    for (let index: number = 0; index < names.length; index++) {
      const path: string = `${base}/${names[index]}`;
      try {
        if (!(await fs.stat(path)).isDirectory()) {
          continue;
        }
      } catch (error) {
        continue;
      }
      out.push({ path: path, used: await CacheQuota.usedOf(path) });
    }
    return out;
  }

  private static async usedOf(dir: string): Promise<number> {
    try {
      const text: string = await fs.readText(`${dir}/${USED}`);
      const value: number = parseInt(text, 10);
      if (!isNaN(value) && value > 0) {
        return value;
      }
    } catch (error) {
    }
    try {
      return Math.max(1, (await fs.stat(dir)).mtime * 1000);
    } catch (error) {
      return 1;
    }
  }

  private static async sizeOf(dir: string): Promise<number> {
    if (dir.length === 0) {
      return 0;
    }
    try {
      if (!fs.accessSync(dir)) {
        return 0;
      }
    } catch (error) {
      return 0;
    }
    let total: number = 0;
    let names: string[] = [];
    try {
      names = await fs.listFile(dir);
    } catch (error) {
      return 0;
    }
    for (let index: number = 0; index < names.length; index++) {
      if (names[index] === USED) {
        continue;
      }
      const path: string = `${dir}/${names[index]}`;
      try {
        const stat: fs.Stat = await fs.stat(path);
        total += stat.isDirectory() ? await CacheQuota.sizeOf(path) : stat.size;
      } catch (error) {
      }
    }
    return total;
  }
}
