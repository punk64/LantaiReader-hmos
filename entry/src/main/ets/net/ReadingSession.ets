import { deviceInfo } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { LantaiSession, SessionResponse } from './LantaiSession';
import { offlineDb, ReadingRow } from '../data/OfflineDb';
import { Prefs } from '../model/Prefs';
import { J } from '../common/Json';

const KEY_DEVICE: string = 'deviceId';
const CLIENT: string = 'lantai-harmony/0.1.0';
const HEARTBEAT_MS: number = 20000;
const FLUSH_BATCH: number = 100;
const FLUSH_ROUNDS: number = 10;
const SEAL_GAP_MS: number = 300000;
const STALE_MS: number = 1800000;

interface HeartbeatBody {
  bookId: string;
  page: number;
  deviceId: string;
  deviceName: string;
  client: string;
}

interface StopBody {
  bookId: string;
  deviceId: string;
}

interface SyncDevice {
  id: string;
  name: string;
}

interface SyncSession {
  clientSessionId: string;
  bookId: string;
  startedAt: string;
  endedAt: string;
  durationMs: number;
  startPage: number;
  lastPage: number;
  pagesRead: number;
  client: string;
}

interface SyncBody {
  device: SyncDevice;
  sessions: SyncSession[];
}

interface FlushOutcome {
  confirmed: number;
  dropped: number;
  moved: boolean;
}

export interface SessionFlushReport {
  sent: number;
  dropped: number;
  failed: number;
  remaining: number;
}

function missingBook(status: number): boolean {
  return status === 404 || status === 410;
}

export class ReadingSession {
  private session: LantaiSession | null = null;
  private deviceId: string = '';
  private deviceName: string = '';
  private bookId: string = '';
  private clientId: string = '';
  private startedAt: string = '';
  private startPage: number = 0;
  private lastPage: number = 0;
  private activeMs: number = 0;
  private segmentAt: number = 0;
  private hiddenAt: number = 0;
  private timer: number = -1;
  private online: boolean = true;
  private flushing: boolean = false;

  attach(session: LantaiSession): void {
    this.session = session;
  }

  async init(): Promise<void> {
    let id: string = Prefs.read(KEY_DEVICE);
    if (id.length === 0) {
      id = util.generateRandomUUID(false);
      await Prefs.write(KEY_DEVICE, id);
    }
    this.deviceId = id;
    const model: string = deviceInfo.productModel;
    this.deviceName = model.length > 0 ? model : 'HarmonyOS';
  }

  active(): boolean {
    return this.clientId.length > 0;
  }

  async start(bookId: string, page: number, incognito: boolean): Promise<void> {
    if (incognito || bookId.length === 0 || this.deviceId.length === 0) {
      return;
    }
    await this.stop();
    const previous: ReadingRow | null = await this.recover(bookId);
    const now: number = Date.now();
    if (previous !== null) {
      this.clientId = previous.clientId;
      this.startedAt = previous.startedAt;
      this.startPage = previous.startPage;
      this.activeMs = previous.durationMs;
      this.lastPage = previous.lastPage > page ? previous.lastPage : page;
    } else {
      this.clientId = util.generateRandomUUID(false);
      this.startedAt = new Date(now).toISOString();
      this.startPage = page;
      this.lastPage = page;
      this.activeMs = 0;
    }
    this.bookId = bookId;
    this.segmentAt = now;
    this.hiddenAt = 0;
    this.online = true;
    await this.persist('open');
    this.beat();
    this.armTimer();
  }

  track(page: number): void {
    if (this.clientId.length === 0 || page <= 0) {
      return;
    }
    if (page <= this.lastPage) {
      return;
    }
    this.lastPage = page;
    this.persist('open');
  }

  async pause(): Promise<void> {
    if (this.clientId.length === 0) {
      return;
    }
    this.accrue();
    this.segmentAt = 0;
    this.disarmTimer();
    this.hiddenAt = Date.now();
    await this.persist('open');
    this.beat();
  }

  async resume(): Promise<void> {
    if (this.clientId.length === 0) {
      this.hiddenAt = 0;
      return;
    }
    const now: number = Date.now();
    const away: number = this.hiddenAt > 0 ? now - this.hiddenAt : 0;
    if (away > SEAL_GAP_MS) {
      const bookId: string = this.bookId;
      const page: number = this.lastPage;
      this.hiddenAt = 0;
      await this.stop();
      await this.start(bookId, page, false);
      return;
    }
    this.hiddenAt = 0;
    this.segmentAt = now;
    this.armTimer();
    this.beat();
  }

  setForeground(value: boolean): void {
    if (value) {
      this.resume();
      return;
    }
    this.pause();
  }

  async stop(): Promise<void> {
    if (this.clientId.length === 0) {
      return;
    }
    this.accrue();
    this.segmentAt = 0;
    this.disarmTimer();
    const id: string = this.clientId;
    const bookId: string = this.bookId;
    const session: LantaiSession | null = this.session;
    let settled: boolean = false;
    if (this.online && session !== null && session.ready()) {
      const body: StopBody = { bookId: bookId, deviceId: this.deviceId };
      try {
        const status: number = await session.sendJson('POST', '/api/lantai/v1/reading/stop',
          JSON.stringify(body));
        settled = (status >= 200 && status < 300) || missingBook(status);
      } catch (error) {
        settled = false;
      }
    }
    if (settled) {
      try {
        await offlineDb.dropReading(id);
      } catch (error) {
      }
    } else {
      await this.persist('pending');
    }
    this.clientId = '';
    this.bookId = '';
    this.startedAt = '';
    this.startPage = 0;
    this.lastPage = 0;
    this.activeMs = 0;
    this.online = true;
    this.hiddenAt = 0;
    if (session !== null && session.ready()) {
      this.flush(session);
    }
  }

  async pendingCount(): Promise<number> {
    if (!offlineDb.ready()) {
      return 0;
    }
    try {
      return await offlineDb.pendingReadingCount();
    } catch (error) {
      return 0;
    }
  }

  async flush(session: LantaiSession,
    onTick: ((done: number, total: number) => void) | null = null): Promise<SessionFlushReport> {
    const report: SessionFlushReport = { sent: 0, dropped: 0, failed: 0, remaining: 0 };
    if (this.flushing || !offlineDb.ready() || !session.ready() || this.deviceId.length === 0) {
      report.remaining = await this.pendingCount();
      return report;
    }
    this.flushing = true;
    try {
      await this.sealStale();
      const total: number = await this.pendingCount();
      let done: number = 0;
      let rounds: number = 0;
      while (rounds < FLUSH_ROUNDS) {
        rounds += 1;
        const rows: ReadingRow[] = await offlineDb.pendingReadings(FLUSH_BATCH);
        if (rows.length === 0) {
          break;
        }
        const outcome: FlushOutcome = await this.push(session, rows);
        report.sent += outcome.confirmed;
        report.dropped += outcome.dropped;
        done += outcome.confirmed + outcome.dropped;
        if (onTick !== null) {
          onTick(done, total);
        }
        if (!outcome.moved) {
          report.failed += 1;
          break;
        }
      }
    } catch (error) {
      report.failed += 1;
    } finally {
      this.flushing = false;
      report.remaining = await this.pendingCount();
    }
    return report;
  }

  private async push(session: LantaiSession, rows: ReadingRow[]): Promise<FlushOutcome> {
    const sessions: SyncSession[] = [];
    for (let index = 0; index < rows.length; index++) {
      const row: ReadingRow = rows[index];
      sessions.push({
        clientSessionId: row.clientId,
        bookId: row.bookId,
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        durationMs: row.durationMs,
        startPage: row.startPage,
        lastPage: row.lastPage,
        pagesRead: row.pagesRead,
        client: CLIENT
      });
    }
    const device: SyncDevice = { id: this.deviceId, name: this.deviceName };
    const body: SyncBody = { device: device, sessions: sessions };
    let response: SessionResponse | null = null;
    try {
      response = await session.request(http.RequestMethod.POST, '/api/lantai/v1/reading/sync',
        JSON.stringify(body));
    } catch (error) {
      return { confirmed: 0, dropped: 0, moved: false };
    }
    if (response.status < 200 || response.status >= 300) {
      return { confirmed: 0, dropped: 0, moved: false };
    }
    const map: Record<string, Object> = J.parse(session.decodeText(response.bytes));
    const confirmed: string[] = J.strList(map, 'confirmed');
    let count: number = 0;
    for (let index = 0; index < confirmed.length; index++) {
      try {
        await offlineDb.dropReading(confirmed[index]);
        count += 1;
      } catch (error) {
      }
    }
    const rejected: Object[] = J.list(map, 'rejected');
    let dropped: number = 0;
    for (let index = 0; index < rejected.length; index++) {
      const item: Record<string, Object> = rejected[index] as Record<string, Object>;
      if (await this.reject(J.str(item, 'clientSessionId'), J.str(item, 'reason'))) {
        dropped += 1;
      }
    }
    return { confirmed: count, dropped: dropped, moved: true };
  }

  private async reject(clientId: string, reason: string): Promise<boolean> {
    if (clientId.length === 0) {
      return false;
    }
    try {
      if (reason === 'future_timestamp') {
        return false;
      }
      if (reason === 'duration_mismatch') {
        const rows: ReadingRow[] = await offlineDb.pendingReadings(FLUSH_BATCH);
        for (let index = 0; index < rows.length; index++) {
          if (rows[index].clientId !== clientId) {
            continue;
          }
          if (rows[index].retry < 1) {
            await offlineDb.bumpReading(clientId);
            return false;
          }
          break;
        }
      }
      await offlineDb.dropReading(clientId);
      return true;
    } catch (error) {
      return false;
    }
  }

  private async sealStale(): Promise<void> {
    let row: ReadingRow | null = null;
    try {
      row = await offlineDb.openReading();
    } catch (error) {
      return;
    }
    if (row === null) {
      return;
    }
    if (this.clientId.length > 0 && row.clientId === this.clientId) {
      return;
    }
    if (Date.now() - row.at < STALE_MS) {
      return;
    }
    await this.sealRow(row, row.at);
  }

  private async recover(bookId: string): Promise<ReadingRow | null> {
    let row: ReadingRow | null = null;
    try {
      row = await offlineDb.openReading();
    } catch (error) {
      return null;
    }
    if (row === null) {
      return null;
    }
    if (row.bookId === bookId && row.clientId.length > 0) {
      return row;
    }
    await this.sealRow(row, Date.now());
    return null;
  }

  private async sealRow(row: ReadingRow, endMs: number): Promise<void> {
    const sealed: ReadingRow = {
      clientId: row.clientId,
      bookId: row.bookId,
      startedAt: row.startedAt,
      endedAt: new Date(endMs).toISOString(),
      durationMs: row.durationMs,
      startPage: row.startPage,
      lastPage: row.lastPage,
      pagesRead: row.lastPage > row.startPage ? row.lastPage - row.startPage : 0,
      state: 'pending',
      retry: row.retry,
      at: Date.now()
    };
    try {
      await offlineDb.saveReading(sealed);
    } catch (error) {
    }
  }

  private accrue(): void {
    if (this.segmentAt <= 0) {
      return;
    }
    const now: number = Date.now();
    const delta: number = now - this.segmentAt;
    if (delta > 0) {
      this.activeMs += delta;
    }
    this.segmentAt = now;
  }

  private async persist(state: string): Promise<void> {
    if (!offlineDb.ready() || this.clientId.length === 0) {
      return;
    }
    const pages: number = this.lastPage > this.startPage ? this.lastPage - this.startPage : 0;
    const row: ReadingRow = {
      clientId: this.clientId,
      bookId: this.bookId,
      startedAt: this.startedAt,
      endedAt: state === 'open' ? '' : new Date().toISOString(),
      durationMs: this.activeMs,
      startPage: this.startPage,
      lastPage: this.lastPage,
      pagesRead: pages,
      state: state,
      retry: 0,
      at: Date.now()
    };
    try {
      await offlineDb.saveReading(row);
    } catch (error) {
    }
  }

  private beat(): void {
    if (this.clientId.length === 0) {
      return;
    }
    this.accrue();
    this.persist('open');
    const session: LantaiSession | null = this.session;
    if (!this.online || session === null || !session.ready()) {
      this.online = false;
      return;
    }
    const body: HeartbeatBody = {
      bookId: this.bookId,
      page: this.lastPage,
      deviceId: this.deviceId,
      deviceName: this.deviceName,
      client: CLIENT
    };
    const id: string = this.clientId;
    session.sendJson('POST', '/api/lantai/v1/reading/heartbeat', JSON.stringify(body))
      .then((status: number) => {
        if (missingBook(status)) {
          this.discard(id);
          return;
        }
        this.online = status >= 200 && status < 300;
      })
      .catch((error: Error) => {
        this.online = false;
      });
  }

  private async discard(id: string): Promise<void> {
    if (id.length === 0 || this.clientId !== id) {
      return;
    }
    this.accrue();
    this.segmentAt = 0;
    this.disarmTimer();
    this.clientId = '';
    this.bookId = '';
    this.startedAt = '';
    this.startPage = 0;
    this.lastPage = 0;
    this.activeMs = 0;
    this.online = false;
    this.hiddenAt = 0;
    try {
      await offlineDb.dropReading(id);
    } catch (error) {
    }
  }

  private armTimer(): void {
    if (this.timer >= 0) {
      return;
    }
    this.timer = setInterval(() => {
      this.beat();
    }, HEARTBEAT_MS);
  }

  private disarmTimer(): void {
    if (this.timer < 0) {
      return;
    }
    clearInterval(this.timer);
    this.timer = -1;
  }
}

export const readingTracker: ReadingSession = new ReadingSession();
