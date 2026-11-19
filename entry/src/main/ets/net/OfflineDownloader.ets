import { common } from '@kit.AbilityKit';
import { connection } from '@kit.NetworkKit';
import { LantaiSession, SessionResponse } from './LantaiSession';
import { BookItem } from '../model/LantaiModels';
import { offlineCache } from './OfflineCache';
import { offlineDb, JobRow } from '../data/OfflineDb';
import { backgroundTask } from './BackgroundTask';
import { Prefs } from '../model/Prefs';

import { t } from '../common/I18n';
const IMG: RegExp = /(?:src|href)="([^"]+)"/g;

interface PullResult {
  body: ArrayBuffer;
  size: number;
}

export class OfflineDownloader {
  private session: LantaiSession | null = null;
  private ctx: common.UIAbilityContext | null = null;
  private busy: boolean = false;
  private paused: Set<string> = new Set<string>();
  private stopped: Set<string> = new Set<string>();
  private listeners: Array<() => void> = [];
  current: string = '';

  attach(session: LantaiSession, ctx: common.UIAbilityContext | null): void {
    this.session = session;
    this.ctx = ctx;
  }

  on(fn: () => void): void {
    this.listeners.push(fn);
  }

  off(fn: () => void): void {
    const index: number = this.listeners.indexOf(fn);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  private emit(): void {
    for (let index = 0; index < this.listeners.length; index++) {
      try {
        this.listeners[index]();
      } catch (error) {
      }
    }
  }

  async reset(): Promise<void> {
    if (!offlineDb.ready()) {
      return;
    }
    const rows: JobRow[] = await offlineDb.jobs();
    for (let index = 0; index < rows.length; index++) {
      const row: JobRow = rows[index];
      if (row.state === 'RUNNING') {
        await offlineDb.patchJob(row.bookId, 'PAUSED', row.total, row.done, row.bytes, t('上次未完成'));
      }
    }
    this.emit();
  }

  async enqueue(book: BookItem, profile: string): Promise<void> {
    if (!offlineDb.ready() || !offlineCache.ready()) {
      return;
    }
    const existed: JobRow[] = await offlineDb.jobs();
    for (let index = 0; index < existed.length; index++) {
      if (existed[index].bookId === book.id && existed[index].state === 'DONE') {
        return;
      }
    }
    const job: JobRow = {
      bookId: book.id,
      title: book.title,
      profile: profile,
      state: 'PENDING',
      total: 0,
      done: 0,
      bytes: 0,
      pages: book.pages,
      size: book.sizeBytes,
      at: Date.now(),
      msg: ''
    };
    await offlineDb.saveJob(job);
    this.stopped.delete(book.id);
    this.paused.delete(book.id);
    this.emit();
    this.pump();
  }

  async pump(): Promise<void> {
    if (this.busy || this.session === null || !offlineDb.ready()) {
      return;
    }
    const rows: JobRow[] = await offlineDb.jobs();
    let next: JobRow | null = null;
    for (let index = 0; index < rows.length; index++) {
      if (rows[index].state === 'PENDING') {
        next = rows[index];
        break;
      }
    }
    if (next === null) {
      return;
    }
    this.busy = true;
    this.current = next.bookId;
    await offlineDb.patchJob(next.bookId, 'RUNNING', next.total, next.done, next.bytes, '');
    this.emit();
    if (this.ctx !== null) {
      await backgroundTask.acquire(this.ctx);
    }
    try {
      await this.run(next);
    } catch (error) {
      const message: string = (error as Error).message;
      if (this.stopped.has(next.bookId)) {
        await offlineDb.removeJob(next.bookId);
      } else if (this.paused.has(next.bookId)) {
        await offlineDb.patchJob(next.bookId, 'PAUSED', next.total, next.done, next.bytes, t('已暂停'));
      } else {
        await offlineDb.patchJob(next.bookId, 'FAILED', next.total, next.done, next.bytes,
          message.length > 0 ? message : t('下载失败'));
      }
    }
    offlineCache.flush();
    this.busy = false;
    this.current = '';
    if (this.ctx !== null) {
      await backgroundTask.release(this.ctx);
    }
    this.emit();
    this.pump();
  }

  async pause(bookId: string): Promise<void> {
    this.paused.add(bookId);
    if (this.current !== bookId) {
      await offlineDb.patchJob(bookId, 'PAUSED', 0, 0, 0, t('已暂停'));
    }
    this.emit();
  }

  async resume(bookId: string): Promise<void> {
    this.paused.delete(bookId);
    this.stopped.delete(bookId);
    const rows: JobRow[] = await offlineDb.jobs();
    for (let index = 0; index < rows.length; index++) {
      if (rows[index].bookId === bookId) {
        await offlineDb.saveJob({
          bookId: rows[index].bookId,
          title: rows[index].title,
          profile: rows[index].profile,
          state: 'PENDING',
          total: rows[index].total,
          done: rows[index].done,
          bytes: rows[index].bytes,
          pages: rows[index].pages,
          size: rows[index].size,
          at: Date.now(),
          msg: ''
        });
        break;
      }
    }
    this.emit();
    this.pump();
  }

  async remove(bookId: string): Promise<void> {
    this.stopped.add(bookId);
    offlineCache.drop(bookId);
    await offlineDb.removeJob(bookId);
    await offlineDb.removeBook(bookId);
    this.emit();
  }

  async pauseAll(): Promise<void> {
    const rows: JobRow[] = await offlineDb.jobs();
    for (let index = 0; index < rows.length; index++) {
      const row: JobRow = rows[index];
      if (row.state === 'PENDING' || row.state === 'RUNNING') {
        this.paused.add(row.bookId);
        if (this.current !== row.bookId) {
          await offlineDb.patchJob(row.bookId, 'PAUSED', row.total, row.done, row.bytes, t('已暂停'));
        }
      }
    }
    this.emit();
  }

  async clearDone(): Promise<void> {
    const rows: JobRow[] = await offlineDb.jobs();
    for (let index = 0; index < rows.length; index++) {
      const row: JobRow = rows[index];
      if (row.state === 'DONE' || row.state === 'FAILED') {
        await offlineDb.removeJob(row.bookId);
      }
    }
    this.emit();
  }

  private async metered(): Promise<boolean> {
    if (!Prefs.bool('wifiOnly', true)) {
      return false;
    }
    try {
      const net: connection.NetHandle = await connection.getDefaultNet();
      const caps: connection.NetCapabilities = await connection.getNetCapabilities(net);
      const types: connection.NetBearType[] = caps.bearerTypes;
      if (types.length === 0) {
        return false;
      }
      for (let index: number = 0; index < types.length; index++) {
        const type: connection.NetBearType = types[index];
        if (type === connection.NetBearType.BEARER_WIFI || type === connection.NetBearType.BEARER_ETHERNET) {
          return false;
        }
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  private async run(job: JobRow): Promise<void> {
    if (await this.metered()) {
      this.paused.add(job.bookId);
      await offlineDb.patchJob(job.bookId, 'PAUSED', job.total, job.done, job.bytes, t('等待 WiFi'));
      this.emit();
      return;
    }
    if (job.profile === 'DIVINA') {
      await this.runComic(job);
      return;
    }
    await this.runEpub(job);
  }

  private async runComic(job: JobRow): Promise<void> {
    const total: number = job.pages > 0 ? job.pages : 1;
    let done: number = Math.min(job.done, total);
    let bytes: number = job.bytes;
    await this.tick(job, total, done, bytes, '');
    for (let n = done + 1; n <= total; n++) {
      this.guard(job.bookId);
      const path: string = `/api/v1/books/${job.bookId}/pages/${n}?convert=jpeg`;
      bytes += (await this.pull(job.bookId, path, 'image/jpeg')).size;
      done = n;
      await this.tick(job, total, done, bytes, '');
    }
    await this.complete(job, total, done, bytes);
  }

  private async runEpub(job: JobRow): Promise<void> {
    const base: string = `/api/lantai/v1/read/${job.bookId}`;
    let bytes: number = job.bytes;
    let done: number = 0;
    let total: number = 0;
    bytes += await this.pullSize(job.bookId, `${base}/bootstrap?images=inline&w=0&window=3`, 'application/json');
    bytes += await this.pullSize(job.bookId, `${base}/chapters?outline=true`, 'application/json');
    bytes += await this.pullSize(job.bookId, '/api/v1/fonts/families', 'application/json');
    const outline: ArrayBuffer | null = offlineCache.read(`${base}/chapters?outline=true`);
    if (outline !== null && this.session !== null) {
      const text: string = this.session.decodeText(outline);
      total = this.chapterCount(text);
    }
    if (total <= 0) {
      total = job.pages > 0 ? job.pages : 1;
    }
    const chapters: number = total;
    total += 3;
    done = 3;
    await this.tick(job, total, done, bytes, '');
    const seen: Set<string> = new Set<string>();
    for (let n = 1; n <= chapters; n++) {
      this.guard(job.bookId);
      const path: string = `${base}/chapter/${n}?images=url&w=0&fmt=orig`;
      const pulled: PullResult = await this.pull(job.bookId, path, 'application/json');
      const html: string = this.session !== null ? this.session.decodeText(pulled.body) : '';
      const sources: string[] = this.imageSources(html);
      for (let index = 0; index < sources.length; index++) {
        const src: string = sources[index];
        if (seen.has(src)) {
          continue;
        }
        seen.add(src);
        this.guard(job.bookId);
        bytes += (await this.pull(job.bookId, src, 'image/jpeg')).size;
      }
      done += 1;
      await this.tick(job, total, done, bytes, '');
    }
    await this.complete(job, total, done, bytes);
  }

  private guard(bookId: string): void {
    if (this.paused.has(bookId)) {
      throw new Error(t('已暂停'));
    }
    if (this.stopped.has(bookId)) {
      throw new Error(t('已删除'));
    }
  }

  private async tick(job: JobRow, total: number, done: number, bytes: number, msg: string): Promise<void> {
    offlineCache.flush();
    await offlineDb.patchJob(job.bookId, 'RUNNING', total, done, bytes, msg);
    this.emit();
  }

  private async complete(job: JobRow, total: number, done: number, bytes: number): Promise<void> {
    offlineCache.flush();
    await offlineDb.patchJob(job.bookId, 'DONE', total, done, bytes, '');
    await offlineDb.saveBook({
      bookId: job.bookId,
      title: job.title,
      profile: job.profile,
      items: offlineCache.countOf(job.bookId),
      bytes: offlineCache.sizeOf(job.bookId),
      at: Date.now()
    });
  }

  private async pullSize(bookId: string, path: string, mime: string): Promise<number> {
    return (await this.pull(bookId, path, mime)).size;
  }

  private async pull(bookId: string, path: string, mime: string): Promise<PullResult> {
    const cached: ArrayBuffer | null = offlineCache.read(path);
    if (cached !== null) {
      return { body: cached, size: 0 };
    }
    if (this.session === null) {
      throw new Error(t('尚未登录'));
    }
    const response: SessionResponse = await this.session.fetch(path);
    if (response.status !== 200) {
      throw new Error(t(`下载失败 HTTP ${response.status}`));
    }
    const type: string = response.contentType.length > 0 ? response.contentType : mime;
    const size: number = offlineCache.put(bookId, path, type, response.bytes);
    return { body: response.bytes, size: size };
  }

  private chapterCount(text: string): number {
    try {
      const body: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const total: Object = body['total'];
      if (typeof total === 'number') {
        return total as number;
      }
      const chapters: Object = body['chapters'];
      if (Array.isArray(chapters)) {
        return (chapters as Object[]).length;
      }
    } catch (error) {
      return 0;
    }
    return 0;
  }

  private imageSources(html: string): string[] {
    const out: string[] = [];
    IMG.lastIndex = 0;
    let match: RegExpExecArray | null = IMG.exec(html);
    while (match !== null) {
      const raw: string = match[1];
      if (raw.length > 0 && raw.indexOf('data:') !== 0 && raw.indexOf('http') !== 0 && raw.indexOf('#') !== 0) {
        const path: string = raw.startsWith('/') ? raw : `/${raw}`;
        out.push(path);
      }
      match = IMG.exec(html);
    }
    return out;
  }
}

export const downloader: OfflineDownloader = new OfflineDownloader();
