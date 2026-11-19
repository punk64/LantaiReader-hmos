import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

export interface CacheEntry {
  f: string;
  m: string;
  s: number;
}

interface IndexFile {
  items: Record<string, CacheEntry>;
}

const ROOT: string = 'offline';
const INDEX: string = 'index.json';
const BLOBS: string = 'blobs';
const LAYOUT: string = '.layout';
const LAYOUT_VERSION: string = '2';
const READ: RegExp = /^\/api\/lantai\/v1\/read\/([^/?]+)\//;
const BOOKS: RegExp = /^\/api\/v1\/books\/([^/?]+)\//;

export function bookIdOfPath(path: string): string {
  const read: RegExpMatchArray | null = path.match(READ);
  if (read !== null && read.length > 1) {
    return read[1];
  }
  const books: RegExpMatchArray | null = path.match(BOOKS);
  if (books !== null && books.length > 1) {
    return books[1];
  }
  return '';
}

export function hashName(path: string): string {
  let hash: number = 0x811c9dc5;
  for (let index: number = 0; index < path.length; index++) {
    hash ^= path.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return `${hash.toString(16)}-${path.length.toString(16)}`;
}

export class OfflineCache {
  private root: string = '';
  private server: string = '';
  private maps: Map<string, Map<string, CacheEntry>> = new Map();
  private dirty: Set<string> = new Set();

  setServer(key: string): void {
    if (this.server === key) {
      return;
    }
    this.maps.clear();
    this.dirty.clear();
    this.server = key;
  }

  serverKey(): string {
    return this.server;
  }

  init(ctx: common.Context): void {
    this.root = `${ctx.filesDir}/${ROOT}`;
    if (!fs.accessSync(this.root)) {
      fs.mkdirSync(this.root, true);
    }
    this.ensureLayout();
  }

  private ensureLayout(): void {
    const marker: string = `${this.root}/${LAYOUT}`;
    if (fs.accessSync(marker)) {
      return;
    }
    const target: string = `${this.root}/${this.server}`;
    try {
      if (!fs.accessSync(target)) {
        fs.mkdirSync(target, true);
      }
      const names: string[] = fs.listFileSync(this.root);
      for (let index: number = 0; index < names.length; index++) {
        const name: string = names[index];
        if (name === LAYOUT || name === this.server) {
          continue;
        }
        const from: string = `${this.root}/${name}`;
        try {
          if (fs.statSync(from).isDirectory()) {
            fs.renameSync(from, `${target}/${name}`);
          }
        } catch (error) {
        }
      }
    } catch (error) {
    }
    try {
      const handle: fs.File = fs.openSync(marker, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        const buffer: ArrayBuffer = new util.TextEncoder().encodeInto(LAYOUT_VERSION).buffer as ArrayBuffer;
        fs.writeSync(handle.fd, buffer);
      } finally {
        fs.closeSync(handle);
      }
    } catch (error) {
    }
  }

  ready(): boolean {
    return this.root.length > 0;
  }

  private bookDir(bookId: string): string {
    return `${this.root}/${this.server}/${bookId}`;
  }

  private blobDir(bookId: string): string {
    return `${this.root}/${this.server}/${bookId}/${BLOBS}`;
  }

  private mapOf(bookId: string): Map<string, CacheEntry> {
    const cached: Map<string, CacheEntry> | undefined = this.maps.get(bookId);
    if (cached !== undefined) {
      return cached;
    }
    const map: Map<string, CacheEntry> = new Map();
    const file: string = `${this.bookDir(bookId)}/${INDEX}`;
    if (fs.accessSync(file)) {
      try {
        const text: string = fs.readTextSync(file);
        const parsed: IndexFile = JSON.parse(text) as IndexFile;
        const keys: string[] = Object.keys(parsed.items);
        for (let index: number = 0; index < keys.length; index++) {
          map.set(keys[index], parsed.items[keys[index]]);
        }
      } catch (error) {
      }
    }
    this.maps.set(bookId, map);
    return map;
  }

  has(path: string): boolean {
    const bookId: string = bookIdOfPath(path);
    if (bookId.length === 0) {
      return false;
    }
    const entry: CacheEntry | undefined = this.mapOf(bookId).get(path);
    return entry !== undefined && fs.accessSync(`${this.blobDir(bookId)}/${entry.f}`);
  }

  mimeOf(path: string): string {
    const bookId: string = bookIdOfPath(path);
    if (bookId.length === 0) {
      return '';
    }
    const entry: CacheEntry | undefined = this.mapOf(bookId).get(path);
    return entry === undefined ? '' : entry.m;
  }

  read(path: string): ArrayBuffer | null {
    const bookId: string = bookIdOfPath(path);
    if (bookId.length === 0) {
      return null;
    }
    const entry: CacheEntry | undefined = this.mapOf(bookId).get(path);
    if (entry === undefined) {
      return null;
    }
    const file: string = `${this.blobDir(bookId)}/${entry.f}`;
    try {
      if (!fs.accessSync(file)) {
        return null;
      }
      const size: number = fs.statSync(file).size;
      if (size <= 0) {
        return null;
      }
      const handle: fs.File = fs.openSync(file, fs.OpenMode.READ_ONLY);
      try {
        const buffer: ArrayBuffer = new ArrayBuffer(size);
        fs.readSync(handle.fd, buffer);
        return buffer;
      } finally {
        fs.closeSync(handle);
      }
    } catch (error) {
      return null;
    }
  }

  put(bookId: string, path: string, mime: string, bytes: ArrayBuffer): number {
    if (bookId.length === 0 || bytes.byteLength === 0) {
      return 0;
    }
    const dir: string = this.blobDir(bookId);
    try {
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      const name: string = `${hashName(path)}.bin`;
      const file: string = `${dir}/${name}`;
      const handle: fs.File = fs.openSync(file,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(handle.fd, bytes);
      } finally {
        fs.closeSync(handle);
      }
      const entry: CacheEntry = { f: name, m: mime, s: bytes.byteLength };
      this.mapOf(bookId).set(path, entry);
      this.dirty.add(bookId);
      return bytes.byteLength;
    } catch (error) {
      return 0;
    }
  }

  flush(): void {
    const ids: string[] = Array.from(this.dirty);
    for (let index: number = 0; index < ids.length; index++) {
      const bookId: string = ids[index];
      const map: Map<string, CacheEntry> = this.mapOf(bookId);
      const items: Record<string, CacheEntry> = {};
      map.forEach((entry: CacheEntry, key: string) => {
        items[key] = entry;
      });
      const body: IndexFile = { items: items };
      const file: string = `${this.bookDir(bookId)}/${INDEX}`;
      try {
        if (!fs.accessSync(this.bookDir(bookId))) {
          fs.mkdirSync(this.bookDir(bookId), true);
        }
        const handle: fs.File = fs.openSync(file,
          fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try {
          const buffer: ArrayBuffer = new util.TextEncoder().encodeInto(JSON.stringify(body)).buffer as ArrayBuffer;
          fs.writeSync(handle.fd, buffer);
        } finally {
          fs.closeSync(handle);
        }
      } catch (error) {
      }
    }
    this.dirty.clear();
  }

  sizeOf(bookId: string): number {
    let total: number = 0;
    this.mapOf(bookId).forEach((entry: CacheEntry) => {
      total += entry.s;
    });
    return total;
  }

  countOf(bookId: string): number {
    return this.mapOf(bookId).size;
  }

  bookIds(): string[] {
    const base: string = `${this.root}/${this.server}`;
    try {
      if (!fs.accessSync(base)) {
        return [];
      }
      return fs.listFileSync(base).filter((name: string) => {
        return fs.statSync(`${base}/${name}`).isDirectory();
      });
    } catch (error) {
      return [];
    }
  }

  drop(bookId: string): void {
    this.maps.delete(bookId);
    this.dirty.delete(bookId);
    const dir: string = this.bookDir(bookId);
    try {
      if (fs.accessSync(dir)) {
        fs.rmdirSync(dir);
      }
    } catch (error) {
    }
  }

  dropAll(): void {
    this.maps.clear();
    this.dirty.clear();
    const base: string = `${this.root}/${this.server}`;
    try {
      if (fs.accessSync(base)) {
        fs.rmdirSync(base);
      }
      fs.mkdirSync(base, true);
    } catch (error) {
    }
  }
}

export const offlineCache: OfflineCache = new OfflineCache();

export function offlinePage(bookId: string, page: number, convert: string): ArrayBuffer | null {
  return offlineCache.read(`/api/v1/books/${bookId}/pages/${page}?convert=${convert}`);
}
