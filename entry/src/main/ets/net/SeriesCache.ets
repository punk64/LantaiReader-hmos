import { SeriesPage } from '../model/LantaiModels';

interface CacheEntry {
  page: SeriesPage;
  at: number;
}

const TTL_MS: number = 60000;

export class SeriesCache {
  private static pages: Map<string, CacheEntry> = new Map<string, CacheEntry>();
  private static order: string[] = [];
  private static limit: number = 8;

  static keyOf(page: number, size: number, sort: string): string {
    return `${page}:${size}:${sort}`;
  }

  static get(key: string): SeriesPage | undefined {
    const hit: CacheEntry | undefined = SeriesCache.pages.get(key);
    if (hit === undefined) {
      return undefined;
    }
    if (Date.now() - hit.at > TTL_MS) {
      SeriesCache.pages.delete(key);
      SeriesCache.order = SeriesCache.order.filter((item: string) => item !== key);
      return undefined;
    }
    SeriesCache.touch(key);
    return hit.page;
  }

  static put(key: string, page: SeriesPage): void {
    SeriesCache.pages.set(key, { page: page, at: Date.now() });
    SeriesCache.touch(key);
    while (SeriesCache.order.length > SeriesCache.limit) {
      const oldest: string | undefined = SeriesCache.order.shift();
      if (oldest === undefined) {
        break;
      }
      SeriesCache.pages.delete(oldest);
    }
  }

  static clear(): void {
    SeriesCache.pages.clear();
    SeriesCache.order = [];
  }

  private static touch(key: string): void {
    SeriesCache.order = SeriesCache.order.filter((item: string) => item !== key);
    SeriesCache.order.push(key);
  }
}
