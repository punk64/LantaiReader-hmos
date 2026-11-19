import { LantaiSession } from './LantaiSession';
import { LantaiApi, ApiError } from './LantaiApi';
import { offlineDb, JobRow, OfflineBookRow, OutboxRow } from '../data/OfflineDb';
import { downloader } from './OfflineDownloader';
import { SeriesCache } from './SeriesCache';

export interface SweepReport {
  supported: boolean;
  checked: number;
  books: number;
  sessions: number;
  progress: number;
  offline: number;
  offlineIds: string[];
  failed: boolean;
}

const BATCH: number = 200;
const MAX_BOOKS: number = 600;
const FALLBACK_BOOKS: number = 20;
const MARKER: string = '/books/';

function emptyReport(): SweepReport {
  return {
    supported: true, checked: 0, books: 0, sessions: 0, progress: 0,
    offline: 0, offlineIds: [], failed: false
  };
}

function bookIdOfPath(path: string): string {
  const at: number = path.indexOf(MARKER);
  if (at < 0) {
    return '';
  }
  const rest: string = path.substring(at + MARKER.length);
  const slash: number = rest.indexOf('/');
  const id: string = slash > 0 ? rest.substring(0, slash) : rest;
  return id.indexOf('?') >= 0 ? id.substring(0, id.indexOf('?')) : id;
}

export class OrphanSweep {
  private running: boolean = false;

  async run(session: LantaiSession, api: LantaiApi, purgeOffline: boolean = false): Promise<SweepReport> {
    const report: SweepReport = emptyReport();
    if (this.running || !offlineDb.ready() || !session.ready()) {
      report.failed = true;
      return report;
    }
    this.running = true;
    try {
      const ids: string[] = [];
      const seen: Set<string> = new Set<string>();
      const offlineIds: Set<string> = new Set<string>();

      const readings: string[] = await offlineDb.readingBookIds();
      for (let index = 0; index < readings.length; index++) {
        this.add(ids, seen, readings[index]);
      }
      const queued: OutboxRow[] = await offlineDb.outboxAll();
      for (let index = 0; index < queued.length; index++) {
        this.add(ids, seen, bookIdOfPath(queued[index].path));
      }
      const books: OfflineBookRow[] = await offlineDb.books();
      for (let index = 0; index < books.length; index++) {
        if (this.add(ids, seen, books[index].bookId)) {
          offlineIds.add(books[index].bookId);
        }
      }
      const jobs: JobRow[] = await offlineDb.jobs();
      for (let index = 0; index < jobs.length; index++) {
        if (this.add(ids, seen, jobs[index].bookId)) {
          offlineIds.add(jobs[index].bookId);
        }
      }
      report.checked = ids.length;
      if (ids.length === 0) {
        return report;
      }
      const target: string[] = ids.length > MAX_BOOKS ? ids.slice(0, MAX_BOOKS) : ids;
      const missing: string[] = await this.probe(api, target, report);
      if (report.failed) {
        return report;
      }
      report.books = missing.length;
      if (missing.length > 0) {
        SeriesCache.clear();
      }
      for (let index = 0; index < missing.length; index++) {
        const id: string = missing[index];
        try {
          report.sessions += await offlineDb.dropReadingsByBook(id);
        } catch (error) {
        }
        try {
          report.progress += await offlineDb.dropOutboxByBook(id);
        } catch (error) {
        }
        if (offlineIds.has(id)) {
          report.offline += 1;
          if (purgeOffline) {
            try {
              await downloader.remove(id);
              report.offlineIds.push(id);
            } catch (error) {
            }
          } else {
            report.offlineIds.push(id);
          }
        }
      }
    } catch (error) {
      report.failed = true;
    } finally {
      this.running = false;
    }
    return report;
  }

  private async probe(api: LantaiApi, ids: string[], report: SweepReport): Promise<string[]> {
    const missing: string[] = [];
    for (let start = 0; start < ids.length; start += BATCH) {
      const chunk: string[] = ids.slice(start, start + BATCH);
      try {
        const result: string[] = await api.booksMissing(chunk);
        for (let index = 0; index < result.length; index++) {
          if (chunk.indexOf(result[index]) >= 0 && missing.indexOf(result[index]) < 0) {
            missing.push(result[index]);
          }
        }
      } catch (error) {
        const status: number = error instanceof ApiError ? error.status : 0;
        if (status !== 404 && status !== 405) {
          report.failed = true;
          return [];
        }
        report.supported = false;
        return await this.probeOneByOne(api, ids, report);
      }
    }
    return missing;
  }

  private async probeOneByOne(api: LantaiApi, ids: string[], report: SweepReport): Promise<string[]> {
    const missing: string[] = [];
    const limit: number = ids.length > FALLBACK_BOOKS ? FALLBACK_BOOKS : ids.length;
    for (let index = 0; index < limit; index++) {
      try {
        await api.book(ids[index]);
      } catch (error) {
        const status: number = error instanceof ApiError ? error.status : 0;
        if (status === 404 || status === 410) {
          missing.push(ids[index]);
        }
      }
    }
    return missing;
  }

  private add(ids: string[], seen: Set<string>, bookId: string): boolean {
    if (bookId.length === 0 || bookId.startsWith('local:')) {
      return false;
    }
    if (seen.has(bookId)) {
      return false;
    }
    seen.add(bookId);
    ids.push(bookId);
    return true;
  }
}

export const orphanSweep: OrphanSweep = new OrphanSweep();
