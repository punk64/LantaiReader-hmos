import { LantaiSession } from './LantaiSession';
import { offlineDb, OutboxRow } from '../data/OfflineDb';

export interface FlushReport {
  sent: number;
  dropped: number;
  failed: number;
  remaining: number;
}

function emptyReport(): FlushReport {
  return { sent: 0, dropped: 0, failed: 0, remaining: 0 };
}

export class ProgressOutbox {
  private flushing: boolean = false;

  async enqueue(method: string, path: string, body: string): Promise<void> {
    if (!offlineDb.ready()) {
      return;
    }
    try {
      await offlineDb.queue(method, path, body.length > 4096 ? body.substring(0, 4096) : body);
    } catch (error) {
    }
  }

  async flush(session: LantaiSession,
    onTick: ((done: number, total: number) => void) | null = null): Promise<FlushReport> {
    const report: FlushReport = emptyReport();
    if (!offlineDb.ready()) {
      return report;
    }
    if (!session.ready() || this.flushing) {
      report.remaining = await this.count();
      return report;
    }
    this.flushing = true;
    try {
      const rows: OutboxRow[] = await offlineDb.outbox();
      const total: number = rows.length;
      for (let index = 0; index < rows.length; index++) {
        const row: OutboxRow = rows[index];
        let status: number = 0;
        try {
          status = await session.sendJson(row.method, row.path, row.body);
        } catch (error) {
          report.failed += 1;
          break;
        }
        if (status >= 200 && status < 400) {
          await offlineDb.dropOutbox(row.id);
          report.sent += 1;
        } else if (status === 401 || status === 403 || status === 429 || status >= 500) {
          report.failed += 1;
          break;
        } else {
          await offlineDb.dropOutbox(row.id);
          report.dropped += 1;
        }
        if (onTick !== null) {
          onTick(index + 1, total);
        }
      }
    } catch (error) {
      report.failed += 1;
    } finally {
      this.flushing = false;
      report.remaining = await this.count();
    }
    return report;
  }

  async dropBooks(bookIds: string[]): Promise<number> {
    if (!offlineDb.ready()) {
      return 0;
    }
    let dropped: number = 0;
    for (let index = 0; index < bookIds.length; index++) {
      try {
        dropped += await offlineDb.dropOutboxByBook(bookIds[index]);
      } catch (error) {
      }
    }
    return dropped;
  }

  async count(): Promise<number> {
    if (!offlineDb.ready()) {
      return 0;
    }
    try {
      return await offlineDb.outboxCount();
    } catch (error) {
      return 0;
    }
  }
}

export const progressOutbox: ProgressOutbox = new ProgressOutbox();
