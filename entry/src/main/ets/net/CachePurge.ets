import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { comicArchive } from './ComicArchive';
import { CacheQuota } from './CacheQuota';

export class CachePurge {
  static init(ctx: common.Context): void {
    CacheQuota.init(ctx);
  }

  static async measure(): Promise<number> {
    return await CacheQuota.measure();
  }

  static async purge(): Promise<number> {
    const before: number = await CacheQuota.measure();
    try {
      await comicArchive.clearAll();
    } catch (error) {
    }
    const roots: string[] = CacheQuota.paths();
    for (let index: number = 0; index < roots.length; index++) {
      await CachePurge.wipe(roots[index]);
    }
    const after: number = await CacheQuota.measure();
    return before > after ? before - after : before;
  }

  private static async wipe(dir: string): Promise<void> {
    if (dir.length === 0) {
      return;
    }
    try {
      if (fs.accessSync(dir)) {
        await fs.rmdir(dir);
      }
    } catch (error) {
    }
  }
}
