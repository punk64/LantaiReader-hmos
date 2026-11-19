import { fileIo as fs } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { ICallBack, UnrarApi } from '@ohos/unrar';
import { Config7z, Uncompress } from '@ohos/oh7zip';
import { CacheQuota } from './CacheQuota';
import { LocalFiles } from './LocalFiles';

import { t, tf } from '../common/I18n';
export interface ArchiveBook {
  key: string;
  title: string;
  dir: string;
  pages: string[];
}

const IMAGE_EXT: string[] = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'avif', 'heic'];
const ZIP_EXT: string[] = ['zip', 'cbz'];
const RAR_EXT: string[] = ['rar', 'cbr'];
const SEVEN_EXT: string[] = ['7z', 'cb7'];

function extensionOf(name: string): string {
  const dot: number = name.lastIndexOf('.');
  return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
}

function hashOf(text: string): string {
  let hash: number = 5381;
  for (let index: number = 0; index < text.length; index++) {
    hash = ((hash << 5) + hash + text.charCodeAt(index)) & 0x7fffffff;
  }
  return hash.toString(36);
}

function chunksOf(name: string): string[] {
  const raw: string[] = name.toLowerCase().split(/(\d+)/);
  const out: string[] = [];
  for (let index: number = 0; index < raw.length; index++) {
    if (raw[index].length > 0) {
      out.push(raw[index]);
    }
  }
  return out;
}

function naturalCompare(left: string, right: string): number {
  const a: string[] = chunksOf(left);
  const b: string[] = chunksOf(right);
  const size: number = Math.min(a.length, b.length);
  for (let index: number = 0; index < size; index++) {
    const x: string = a[index];
    const y: string = b[index];
    const nx: number = parseInt(x, 10);
    const ny: number = parseInt(y, 10);
    if (!Number.isNaN(nx) && !Number.isNaN(ny)) {
      if (nx !== ny) {
        return nx - ny;
      }
    } else if (x !== y) {
      return x < y ? -1 : 1;
    }
  }
  return a.length - b.length;
}

export class ComicArchive {
  private base: string = '';
  private cache: Map<string, ArchiveBook> = new Map<string, ArchiveBook>();

  init(ctx: common.Context): void {
    if (this.base.length === 0) {
      this.base = `${ctx.cacheDir}/archive`;
    }
  }

  ready(): boolean {
    return this.base.length > 0;
  }

  static isArchive(name: string): boolean {
    const ext: string = extensionOf(name);
    return ZIP_EXT.includes(ext) || RAR_EXT.includes(ext) || SEVEN_EXT.includes(ext);
  }

  static isReadable(name: string): boolean {
    const ext: string = extensionOf(name);
    return ZIP_EXT.includes(ext) || RAR_EXT.includes(ext) || SEVEN_EXT.includes(ext);
  }

  async open(path: string, name: string, size: number): Promise<ArchiveBook> {
    if (this.base.length === 0) {
      throw new Error(t('压缩包缓存目录未初始化'));
    }
    if (!ComicArchive.isArchive(name)) {
      throw new Error(tf('不支持的压缩包格式：{0}', [extensionOf(name).toUpperCase()]));
    }
    const ext: string = extensionOf(name);
    let bytes: number = size;
    if (bytes <= 0) {
      try {
        bytes = (await fs.stat(path)).size;
      } catch (error) {
      }
    }
    const key: string = `${bytes.toString(36)}${hashOf(path)}`;
    const hit: ArchiveBook | undefined = this.cache.get(key);
    if (hit !== undefined) {
      return hit;
    }
    const dir: string = `${this.base}/${key}`;
    let pages: string[] = await this.collect(dir);
    if (pages.length === 0) {
      LocalFiles.ensureDir(dir);
      if (ZIP_EXT.includes(ext)) {
        await zlib.decompressFile(path, dir);
      } else if (RAR_EXT.includes(ext)) {
        await this.expandRar(path, dir);
      } else {
        await this.expandSeven(path, dir);
      }
      pages = await this.collect(dir);
    }
    if (pages.length === 0) {
      throw new Error(t('压缩包内没有可显示的图片'));
    }
    const book: ArchiveBook = { key: key, title: name, dir: dir, pages: pages };
    this.cache.set(key, book);
    CacheQuota.touch(dir);
    await this.applyQuota(key);
    return book;
  }

  private async applyQuota(keep: string): Promise<void> {
    const freed: number = await CacheQuota.enforce(`${this.base}/${keep}`);
    if (freed <= 0) {
      return;
    }
    const stale: string[] = [];
    this.cache.forEach((value: ArchiveBook, key: string) => {
      if (key !== keep) {
        stale.push(key);
      }
    });
    for (let index: number = 0; index < stale.length; index++) {
      this.cache.delete(stale[index]);
    }
  }

  private async expandRar(path: string, dir: string): Promise<void> {
    if (UnrarApi.isEncrypted(path) === 1) {
      throw new Error(t('RAR 压缩包已加密，暂不支持输入密码'));
    }
    await new Promise<void>((resolve: () => void) => {
      const callback: ICallBack = {
        callBackResult: (value: string) => {
          resolve();
        }
      };
      UnrarApi.RarFiles_Extract(path, dir, callback);
    });
  }

  private async expandSeven(path: string, dir: string): Promise<void> {
    const config: Config7z = { src: path, dst: dir };
    const code: number = await new Uncompress().extractAsync(config);
    if (code === 10) {
      throw new Error(t('7Z 压缩包已加密，暂不支持输入密码'));
    }
    if (code !== 0) {
      throw new Error(t(`7Z 解压失败（错误码 ${code}）`));
    }
  }

  async readPage(book: ArchiveBook, n: number): Promise<ArrayBuffer> {
    const index: number = n - 1;
    if (index < 0 || index >= book.pages.length) {
      throw new Error(t('页码超出范围'));
    }
    CacheQuota.touch(book.dir);
    const path: string = book.pages[index];
    const info: fs.Stat = await fs.stat(path);
    const size: number = info.size;
    if (size <= 0) {
      throw new Error(t('页文件为空'));
    }
    const buffer: ArrayBuffer = new ArrayBuffer(size);
    const file: fs.File = await fs.open(path, fs.OpenMode.READ_ONLY);
    try {
      const filled: number = await fs.read(file.fd, buffer, { offset: 0, length: size });
      if (filled !== size) {
        throw new Error(t(`页读取不完整 ${filled}/${size}`));
      }
    } finally {
      await fs.close(file);
    }
    return buffer;
  }

  async clear(book: ArchiveBook): Promise<void> {
    this.cache.delete(book.key);
    await this.drop(book.dir);
  }

  async clearAll(): Promise<void> {
    this.cache.clear();
    await this.drop(this.base);
  }

  private async drop(dir: string): Promise<void> {
    try {
      await fs.rmdir(dir);
    } catch (error) {
    }
  }

  private async collect(dir: string): Promise<string[]> {
    const out: string[] = [];
    await this.walk(dir, out, 0);
    out.sort((left: string, right: string) => naturalCompare(left, right));
    return out;
  }

  private async walk(dir: string, out: string[], depth: number): Promise<void> {
    if (depth > 6) {
      return;
    }
    let names: string[] = [];
    try {
      names = await fs.listFile(dir);
    } catch (error) {
      return;
    }
    for (let index: number = 0; index < names.length; index++) {
      const name: string = names[index];
      if (name === '.' || name === '..' || name === '.DS_Store') {
        continue;
      }
      if (name === '__MACOSX') {
        continue;
      }
      const child: string = `${dir}/${name}`;
      let info: fs.Stat;
      try {
        info = await fs.stat(child);
      } catch (error) {
        continue;
      }
      if (info.isDirectory()) {
        await this.walk(child, out, depth + 1);
      } else if (IMAGE_EXT.includes(extensionOf(name))) {
        out.push(child);
      }
    }
  }
}

export const comicArchive: ComicArchive = new ComicArchive();
