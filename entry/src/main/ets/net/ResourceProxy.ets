import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LantaiSession, SessionResponse } from './LantaiSession';
import { ProxyStat, emptyStat } from '../model/ProbeModel';
import { offlineCache } from './OfflineCache';
import { progressOutbox } from './ProgressOutbox';
import { LocalAsset, localBookSource } from './LocalBookSource';

export const VIRTUAL_ORIGIN: string = 'https://lantai.example';
export const ENTRY_FILE: string = 'ebook.html';
const LOCAL_READ: string = '/api/lantai/v1/read/';
const TAG: string = 'LantaiReader';

export type RawReader = (name: string) => ArrayBuffer;

interface ProgressionLocation {
  position: number;
  progression: number;
  totalProgression: number;
}

interface ProgressionLocator {
  href: string;
  type: string;
  locations: ProgressionLocation;
}

interface ProgressionDevice {
  id: string;
  name: string;
}

interface ProgressionBody {
  modified: string;
  device: ProgressionDevice;
  locator: ProgressionLocator;
}

export class ResourceProxy {
  private session: LantaiSession;
  private readRaw: RawReader;
  private hidden: () => boolean;
  private onProgress: (path: string) => void;
  stat: ProxyStat = emptyStat();

  constructor(session: LantaiSession, readRaw: RawReader, hidden: () => boolean = () => false,
    onProgress: (path: string) => void = () => {}) {
    this.session = session;
    this.readRaw = readRaw;
    this.hidden = hidden;
    this.onProgress = onProgress;
  }

  resetStat(): void {
    this.stat = emptyStat();
  }

  handle(request: webview.WebSchemeHandlerRequest, handler: webview.WebResourceHandler): boolean {
    const url: string = request.getRequestUrl();
    if (!url.startsWith(VIRTUAL_ORIGIN)) {
      return false;
    }
    const method: string = request.getRequestMethod().toUpperCase();
    if (method === 'OPTIONS') {
      this.finish(handler, 204, 'text/plain', new ArrayBuffer(0));
      return true;
    }
    if (method !== 'GET' && method !== 'HEAD') {
      this.finish(handler, 204, 'text/plain', new ArrayBuffer(0));
      return true;
    }
    this.deliver(url, handler);
    return true;
  }

  private deliver(url: string, handler: webview.WebResourceHandler): void {
    this.respond(url, handler).catch((error: Error) => {
      this.stat.failed += 1;
      this.finish(handler, 502, 'text/plain', new ArrayBuffer(0));
    });
  }

  private async respond(url: string, handler: webview.WebResourceHandler): Promise<void> {
    const started: number = Date.now();
    const path: string = url.substring(VIRTUAL_ORIGIN.length);
    const clean: string = path.split('?')[0];
    this.stat.lastPath = clean;

    if (clean.length === 0 || clean === '/' || clean === `/${ENTRY_FILE}`) {
      this.stat.assets += 1;
      this.finish(handler, 200, 'text/html', this.readRaw(ENTRY_FILE));
      this.stat.lastMs = Date.now() - started;
      return;
    }

    if (!clean.startsWith('/api/')) {
      const name: string = clean.substring(1);
      this.stat.assets += 1;
      const bytes: ArrayBuffer = this.readRaw(name);
      this.finish(handler, 200, this.mimeOf(clean), bytes);
      this.stat.lastMs = Date.now() - started;
      return;
    }

    if (clean.startsWith(LOCAL_READ)) {
      const handled: boolean = await this.deliverLocal(path, clean, handler);
      if (handled) {
        this.stat.api += 1;
        this.stat.lastMs = Date.now() - started;
        return;
      }
    }

    if (clean.startsWith('/api/lantai/v1/annotations') && path.indexOf('local:') >= 0) {
      this.stat.api += 1;
      this.finish(handler, 200, 'application/json', this.encode('[]'));
      this.stat.lastMs = Date.now() - started;
      return;
    }

    if (clean === '/api/lantai/v1/read-progress') {
      this.stat.api += 1;
      await this.saveProgress(path, handler);
      this.stat.lastMs = Date.now() - started;
      return;
    }

    const local: ArrayBuffer | null = this.cachedBody(path);
    if (local !== null) {
      const mime: string = offlineCache.mimeOf(this.cacheKey(path));
      this.stat.cached += 1;
      this.finish(handler, 200, mime.length > 0 ? mime : this.mimeOf(clean), local);
      this.stat.lastMs = Date.now() - started;
      return;
    }

    const timeout: number = clean.indexOf('/bootstrap') >= 0 ? 45000 : 20000;
    const response: SessionResponse = await this.session.fetch(path, '*/*', 0, timeout);
    this.stat.api += 1;
    const mime: string = response.contentType.length > 0 ? response.contentType : this.mimeOf(clean);
    this.finish(handler, response.status, mime, response.bytes);
    this.stat.lastMs = Date.now() - started;
  }

  private async saveProgress(path: string, handler: webview.WebResourceHandler): Promise<void> {
    if (this.hidden()) {
      this.finish(handler, 204, 'text/plain', new ArrayBuffer(0));
      return;
    }
    const book: string = this.queryText(path, 'book');
    const chapter: number = this.queryInt(path, 'ch');
    const progression: number = Number(this.queryText(path, 'p'));
    const total: number = Number(this.queryText(path, 'tp'));
    const href: string = this.queryText(path, 'href');
    if (book.length === 0 || chapter <= 0) {
      this.finish(handler, 400, 'text/plain', new ArrayBuffer(0));
      return;
    }
    const location: ProgressionLocation = {
      position: chapter,
      progression: isNaN(progression) ? 0 : progression,
      totalProgression: isNaN(total) ? 0 : total
    };
    const locator: ProgressionLocator = {
      href: href.length > 0 ? href : `#page=${chapter}`,
      type: 'application/xhtml+xml',
      locations: location
    };
    const device: ProgressionDevice = { id: 'lantai-reader', name: 'LantaiReader' };
    const payload: ProgressionBody = {
      modified: new Date().toISOString(),
      device: device,
      locator: locator
    };
    const body: string = JSON.stringify(payload);
    if (!this.session.ready()) {
      await progressOutbox.enqueue('PUT', `/api/v1/books/${book}/progression`, body);
      this.onProgress(path);
      this.finish(handler, 200, 'application/json', this.encode('{}'));
      return;
    }
    try {
      const response: SessionResponse =
        await this.session.verbs('PUT', `/api/v1/books/${book}/progression`, body);
      this.onProgress(path);
      this.finish(handler, response.status, 'application/json', response.bytes);
    } catch (error) {
      this.onProgress(path);
      this.finish(handler, 502, 'text/plain', new ArrayBuffer(0));
    }
  }

  private async deliverLocal(path: string, clean: string, handler: webview.WebResourceHandler): Promise<boolean> {
    const rest: string = clean.substring(LOCAL_READ.length);
    const slash: number = rest.indexOf('/');
    if (slash <= 0) {
      return false;
    }
    const id: string = rest.substring(0, slash);
    if (!id.startsWith('local:')) {
      return false;
    }
    const tail: string = rest.substring(slash + 1);
    try {
      if (tail === 'bootstrap') {
        const chapter: number = this.queryInt(path, 'chapter');
        hilog.info(0x0000, TAG, 'local bootstrap %{public}s ch=%{public}d', id, chapter);
        const body: string = await localBookSource.bootstrap(id, chapter);
        this.finish(handler, 200, 'application/json', this.encode(body));
        return true;
      }
      if (tail === 'chapters') {
        const body: string = await localBookSource.outline(id);
        this.finish(handler, 200, 'application/json', this.encode(body));
        return true;
      }
      if (tail.startsWith('chapter/')) {
        const n: number = parseInt(tail.substring(8).split('?')[0], 10);
        const body: string = await localBookSource.chapter(id, isNaN(n) ? 1 : n);
        this.finish(handler, 200, 'application/json', this.encode(body));
        return true;
      }
      if (tail === 'asset') {
        const asset: LocalAsset = await localBookSource.asset(id, this.queryText(path, 'p'));
        const ok: boolean = asset.bytes.byteLength > 0;
        this.finish(handler, ok ? 200 : 404, asset.mime, asset.bytes);
        return true;
      }
    } catch (error) {
      hilog.error(0x0000, TAG, 'local %{public}s failed: %{public}s', clean,
        (error as Error).message);
      this.finish(handler, 404, 'text/plain', new ArrayBuffer(0));
      return true;
    }
    return false;
  }

  private queryInt(path: string, key: string): number {
    const value: string = this.queryText(path, key);
    if (value.length === 0) {
      return 0;
    }
    const parsed: number = parseInt(value, 10);
    return isNaN(parsed) ? 0 : parsed;
  }

  private queryText(path: string, key: string): string {
    const mark: number = path.indexOf('?');
    if (mark < 0) {
      return '';
    }
    const parts: string[] = path.substring(mark + 1).split('&');
    for (let index: number = 0; index < parts.length; index++) {
      const eq: number = parts[index].indexOf('=');
      if (eq <= 0 || parts[index].substring(0, eq) !== key) {
        continue;
      }
      const raw: string = parts[index].substring(eq + 1);
      try {
        return decodeURIComponent(raw);
      } catch (error) {
        return raw;
      }
    }
    return '';
  }

  private encode(text: string): ArrayBuffer {
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(text);
    return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  }

  private cacheKey(path: string): string {
    const mark: number = path.indexOf('?');
    if (mark < 0 || path.indexOf('/bootstrap') < 0) {
      return path;
    }
    const parts: string[] = path.substring(mark + 1).split('&');
    const kept: string[] = [];
    for (let index = 0; index < parts.length; index++) {
      if (!parts[index].startsWith('chapter=')) {
        kept.push(parts[index]);
      }
    }
    if (kept.length === parts.length) {
      return path;
    }
    const base: string = path.substring(0, mark);
    return kept.length > 0 ? `${base}?${kept.join('&')}` : base;
  }

  private cachedBody(path: string): ArrayBuffer | null {
    const key: string = this.cacheKey(path);
    if (key === path) {
      return offlineCache.read(path);
    }
    return offlineCache.read(key);
  }

  private mimeOf(path: string): string {
    const clean: string = path.split('?')[0].toLowerCase();
    if (clean.endsWith('.html') || clean.endsWith('.htm')) {
      return 'text/html';
    }
    if (clean.endsWith('.js') || clean.endsWith('.mjs')) {
      return 'text/javascript';
    }
    if (clean.endsWith('.css')) {
      return 'text/css';
    }
    if (clean.endsWith('.json')) {
      return 'application/json';
    }
    if (clean.endsWith('.svg')) {
      return 'image/svg+xml';
    }
    if (clean.endsWith('.png')) {
      return 'image/png';
    }
    if (clean.endsWith('.jpg') || clean.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (clean.endsWith('.webp')) {
      return 'image/webp';
    }
    if (clean.endsWith('.gif')) {
      return 'image/gif';
    }
    if (clean.endsWith('.avif')) {
      return 'image/avif';
    }
    if (clean.endsWith('.woff2')) {
      return 'font/woff2';
    }
    if (clean.endsWith('.woff')) {
      return 'font/woff';
    }
    if (clean.endsWith('.ttf')) {
      return 'font/ttf';
    }
    if (clean.endsWith('.otf')) {
      return 'font/otf';
    }
    return 'application/octet-stream';
  }

  private finish(handler: webview.WebResourceHandler, status: number, mime: string,
    body: ArrayBuffer): void {
    try {
      const response = new webview.WebSchemeHandlerResponse();
      response.setStatus(status);
      response.setStatusText(status === 200 ? 'OK' : `HTTP ${status}`);
      response.setMimeType(mime);
      if (mime.startsWith('text/') || mime === 'application/json') {
        response.setEncoding('utf-8');
      }
      response.setHeaderByName('Access-Control-Allow-Origin', '*', true);
      response.setHeaderByName('Cache-Control', 'no-store', true);
      handler.didReceiveResponse(response);
      if (body.byteLength > 0) {
        handler.didReceiveResponseBody(body);
      }
      handler.didFinish();
    } catch (error) {
    }
  }
}
