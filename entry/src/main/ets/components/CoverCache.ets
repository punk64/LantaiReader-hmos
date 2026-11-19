import { image } from '@kit.ImageKit';
import { appStore } from '../model/AppStore';
import { LocalMetas } from '../net/LocalMeta';

import { t } from '../common/I18n';
export class CoverCache {
  private static cache: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  private static order: string[] = [];
  private static inflight: Map<string, Promise<image.PixelMap>> = new Map<string, Promise<image.PixelMap>>();
  private static limit: number = 48;
  private static fullKey: string = '';
  private static fullToken: number = 0;

  static cached(id: string): image.PixelMap | undefined {
    const hit: image.PixelMap | undefined = CoverCache.cache.get(id);
    if (hit !== undefined) {
      CoverCache.touch(id);
    }
    return hit;
  }

  static cachedSeries(id: string): image.PixelMap | undefined {
    return CoverCache.cached(`series:${id}`);
  }

  static async load(id: string, width: number, series: boolean = false): Promise<image.PixelMap> {
    const key: string = series ? `series:${id}` : id;
    const hit: image.PixelMap | undefined = CoverCache.cache.get(key);
    if (hit !== undefined) {
      CoverCache.touch(key);
      return hit;
    }
    const pending: Promise<image.PixelMap> | undefined = CoverCache.inflight.get(key);
    if (pending !== undefined) {
      return pending;
    }
    const task: Promise<image.PixelMap> = CoverCache.decode(id, width, series);
    CoverCache.inflight.set(key, task);
    try {
      const pix: image.PixelMap = await task;
      CoverCache.put(key, pix);
      return pix;
    } finally {
      CoverCache.inflight.delete(key);
    }
  }

  static async own(id: string, width: number): Promise<image.PixelMap> {
    const hit: image.PixelMap | undefined = CoverCache.cache.get(id);
    if (hit !== undefined) {
      CoverCache.touch(id);
      return await hit.clone();
    }
    return await CoverCache.decode(id, width);
  }

  static async loadFull(id: string): Promise<image.PixelMap> {
    const key: string = `full:${id}`;
    CoverCache.fullToken++;
    if (CoverCache.fullKey.length > 0 && CoverCache.fullKey !== key) {
      CoverCache.forget(CoverCache.fullKey);
    }
    CoverCache.fullKey = key;
    const hit: image.PixelMap | undefined = CoverCache.cache.get(key);
    if (hit !== undefined) {
      CoverCache.touch(key);
      return hit;
    }
    const pending: Promise<image.PixelMap> | undefined = CoverCache.inflight.get(key);
    if (pending !== undefined) {
      return pending;
    }
    const task: Promise<image.PixelMap> = CoverCache.decode(id, 0);
    CoverCache.inflight.set(key, task);
    try {
      const pix: image.PixelMap = await task;
      CoverCache.put(key, pix);
      return pix;
    } finally {
      CoverCache.inflight.delete(key);
    }
  }

  static releaseFull(id: string): void {
    const key: string = `full:${id}`;
    const token: number = ++CoverCache.fullToken;
    setTimeout(() => {
      if (token !== CoverCache.fullToken) {
        return;
      }
      CoverCache.forget(key);
      if (CoverCache.fullKey === key) {
        CoverCache.fullKey = '';
      }
    }, 800);
  }

  static forget(id: string): void {
    const hit: image.PixelMap | undefined = CoverCache.cache.get(id);
    if (hit === undefined) {
      return;
    }
    CoverCache.cache.delete(id);
    CoverCache.order = CoverCache.order.filter((key: string) => key !== id);
    hit.release();
  }

  static clear(): void {
    CoverCache.cache.forEach((pix: image.PixelMap) => {
      pix.release();
    });
    CoverCache.cache.clear();
    CoverCache.order = [];
  }

  private static async decode(id: string, width: number, series: boolean = false): Promise<image.PixelMap> {
    if (id.startsWith('local:')) {
      const path: string = LocalMetas.coverFile(id);
      if (path.length === 0) {
        throw new Error(t('本地书暂无封面'));
      }
      const local: image.ImageSource = image.createImageSource(path);
      try {
        return await CoverCache.decodeSource(local, width);
      } finally {
        local.release();
      }
    }
    const buffer: ArrayBuffer = series ? await appStore.api.seriesCover(id) : await appStore.api.cover(id, width);
    if (buffer.byteLength === 0) {
      throw new Error(t('封面为空'));
    }
    const source: image.ImageSource | undefined = image.createImageSource(buffer);
    if (source === undefined) {
      throw new Error(t('封面解码失败'));
    }
    try {
      return await CoverCache.decodeSource(source, width);
    } finally {
      source.release();
    }
  }

  private static async decodeSource(source: image.ImageSource, width: number): Promise<image.PixelMap> {
    const info: image.ImageInfo = await source.getImageInfo();
    const target: number = width > 0 ? Math.min(width, info.size.width) : info.size.width;
    const ratio: number = info.size.height / Math.max(1, info.size.width);
    const options: image.DecodingOptions = {
      desiredSize: { width: target, height: Math.round(target * ratio) },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    };
    return await source.createPixelMap(options);
  }

  private static put(id: string, pix: image.PixelMap): void {
    const existing: image.PixelMap | undefined = CoverCache.cache.get(id);
    if (existing !== undefined) {
      existing.release();
    }
    CoverCache.cache.set(id, pix);
    CoverCache.touch(id);
    while (CoverCache.order.length > CoverCache.limit) {
      const oldest: string | undefined = CoverCache.order.shift();
      if (oldest === undefined) {
        break;
      }
      const dropped: image.PixelMap | undefined = CoverCache.cache.get(oldest);
      if (dropped !== undefined) {
        CoverCache.cache.delete(oldest);
        dropped.release();
      }
    }
  }

  private static touch(id: string): void {
    CoverCache.order = CoverCache.order.filter((key: string) => key !== id);
    CoverCache.order.push(id);
  }
}
