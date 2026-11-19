import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LocalMeta } from '../net/LocalMeta';

const DB_NAME: string = 'lantai_offline.db';

const CREATE_JOB: string = `CREATE TABLE IF NOT EXISTS JOB (
  server TEXT,
  book_id TEXT,
  title TEXT,
  profile TEXT,
  state TEXT,
  total INTEGER,
  done INTEGER,
  bytes INTEGER,
  pages INTEGER,
  size INTEGER,
  at INTEGER,
  msg TEXT,
  PRIMARY KEY (server, book_id)
)`;

const CREATE_BOOK: string = `CREATE TABLE IF NOT EXISTS OFFLINE_BOOK (
  server TEXT,
  book_id TEXT,
  title TEXT,
  profile TEXT,
  items INTEGER,
  bytes INTEGER,
  at INTEGER,
  PRIMARY KEY (server, book_id)
)`;

const CREATE_OUTBOX: string = `CREATE TABLE IF NOT EXISTS PROGRESS_OUTBOX (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  server TEXT,
  method TEXT,
  path TEXT,
  body TEXT,
  at INTEGER
)`;

const CREATE_READING: string = `CREATE TABLE IF NOT EXISTS READING_SESSION (
  server TEXT,
  client_id TEXT,
  book_id TEXT,
  started_at TEXT,
  ended_at TEXT,
  duration_ms INTEGER,
  start_page INTEGER,
  last_page INTEGER,
  pages_read INTEGER,
  state TEXT,
  retry INTEGER,
  at INTEGER,
  PRIMARY KEY (server, client_id)
)`;

const CREATE_LOCAL: string = `CREATE TABLE IF NOT EXISTS LOCAL_BOOK (
  local_id TEXT PRIMARY KEY,
  uri TEXT,
  name TEXT,
  size INTEGER,
  title TEXT,
  author TEXT,
  series TEXT,
  publisher TEXT,
  date TEXT,
  profile TEXT,
  pages INTEGER,
  kind TEXT,
  cover TEXT,
  root TEXT,
  at INTEGER,
  chapter INTEGER,
  progress REAL
)`;

const JOB_COLUMNS: string[] = ['book_id', 'title', 'profile', 'state', 'total', 'done', 'bytes',
  'pages', 'size', 'at', 'msg'];
const BOOK_COLUMNS: string[] = ['book_id', 'title', 'profile', 'items', 'bytes', 'at'];
const OUTBOX_COLUMNS: string[] = ['id', 'method', 'path', 'body', 'at'];
const READING_COLUMNS: string[] = ['client_id', 'book_id', 'started_at', 'ended_at', 'duration_ms',
  'start_page', 'last_page', 'pages_read', 'state', 'retry', 'at'];

export interface ReadingRow {
  clientId: string;
  bookId: string;
  startedAt: string;
  endedAt: string;
  durationMs: number;
  startPage: number;
  lastPage: number;
  pagesRead: number;
  state: string;
  retry: number;
  at: number;
}

export interface JobRow {
  bookId: string;
  title: string;
  profile: string;
  state: string;
  total: number;
  done: number;
  bytes: number;
  pages: number;
  size: number;
  at: number;
  msg: string;
}

export interface OfflineBookRow {
  bookId: string;
  title: string;
  profile: string;
  items: number;
  bytes: number;
  at: number;
}

export interface OutboxRow {
  id: number;
  method: string;
  path: string;
  body: string;
  at: number;
}

function text(value: relationalStore.ValueType): string {
  return typeof value === 'string' ? value as string : '';
}

function count(value: relationalStore.ValueType): number {
  return typeof value === 'number' ? value as number : 0;
}

export class OfflineDb {
  private store: relationalStore.RdbStore | null = null;
  private server: string = '';

  setServer(key: string): void {
    this.server = key;
  }

  serverKey(): string {
    return this.server;
  }

  async init(ctx: common.Context): Promise<void> {
    if (this.store !== null) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(ctx, config);
    this.store = store;
    await this.migrate();
    await store.executeSql(CREATE_JOB);
    await store.executeSql(CREATE_BOOK);
    await store.executeSql(CREATE_OUTBOX);
    await store.executeSql(CREATE_READING);
    await store.executeSql(CREATE_LOCAL);
  }

  ready(): boolean {
    return this.store !== null;
  }

  private async columnsOf(table: string): Promise<string[]> {
    const out: string[] = [];
    if (this.store === null) {
      return out;
    }
    try {
      const result: relationalStore.ResultSet = await this.store.querySql(`PRAGMA table_info(${table})`);
      const nameIndex: number = result.getColumnIndex('name');
      while (result.goToNextRow()) {
        out.push(text(result.getValue(nameIndex)));
      }
      result.close();
    } catch (error) {
    }
    return out;
  }

  private async migrate(): Promise<void> {
    if (this.store === null) {
      return;
    }
    await this.addLocalColumns();
    const owner: string = this.server.replace(/'/g, "''");
    const job: string[] = await this.columnsOf('JOB');
    const book: string[] = await this.columnsOf('OFFLINE_BOOK');
    const outbox: string[] = await this.columnsOf('PROGRESS_OUTBOX');
    const reading: string[] = await this.columnsOf('READING_SESSION');
    const needJob: boolean = job.length > 0 && !job.includes('server');
    const needBook: boolean = book.length > 0 && !book.includes('server');
    const needOutbox: boolean = outbox.length > 0 && !outbox.includes('server');
    const needReading: boolean = reading.length > 0 && !reading.includes('server');
    if (!needJob && !needBook && !needOutbox && !needReading) {
      return;
    }
    try {
      this.store.beginTransaction();
      if (needJob) {
        await this.rebuild('JOB', CREATE_JOB, JOB_COLUMNS, owner);
      }
      if (needBook) {
        await this.rebuild('OFFLINE_BOOK', CREATE_BOOK, BOOK_COLUMNS, owner);
      }
      if (needOutbox) {
        await this.rebuild('PROGRESS_OUTBOX', CREATE_OUTBOX, OUTBOX_COLUMNS, owner);
      }
      if (needReading) {
        await this.rebuild('READING_SESSION', CREATE_READING, READING_COLUMNS, owner);
      }
      this.store.commit();
    } catch (error) {
      try {
        this.store.rollBack();
      } catch (inner) {
      }
    }
  }

  private async addLocalColumns(): Promise<void> {
    if (this.store === null) {
      return;
    }
    const columns: string[] = await this.columnsOf('LOCAL_BOOK');
    if (columns.length === 0) {
      return;
    }
    try {
      if (!columns.includes('chapter')) {
        await this.store.executeSql('ALTER TABLE LOCAL_BOOK ADD COLUMN chapter INTEGER DEFAULT 0');
      }
      if (!columns.includes('progress')) {
        await this.store.executeSql('ALTER TABLE LOCAL_BOOK ADD COLUMN progress REAL DEFAULT 0');
      }
    } catch (error) {
    }
  }

  private async rebuild(table: string, create: string, columns: string[], owner: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    const legacy: string = `${table}_legacy`;
    await this.store.executeSql(`DROP TABLE IF EXISTS ${legacy}`);
    await this.store.executeSql(`ALTER TABLE ${table} RENAME TO ${legacy}`);
    await this.store.executeSql(create);
    const names: string = columns.join(', ');
    await this.store.executeSql(
      `INSERT INTO ${table} (server, ${names}) SELECT '${owner}', ${names} FROM ${legacy}`);
    await this.store.executeSql(`DROP TABLE ${legacy}`);
  }

  async saveJob(job: JobRow): Promise<void> {
    if (this.store === null) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      'server': this.server,
      'book_id': job.bookId,
      'title': job.title,
      'profile': job.profile,
      'state': job.state,
      'total': job.total,
      'done': job.done,
      'bytes': job.bytes,
      'pages': job.pages,
      'size': job.size,
      'at': job.at,
      'msg': job.msg
    };
    await this.store.insert('JOB', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  async patchJob(bookId: string, state: string, total: number, done: number, bytes: number, msg: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      'state': state,
      'total': total,
      'done': done,
      'bytes': bytes,
      'at': Date.now(),
      'msg': msg
    };
    const predicates: relationalStore.RdbPredicates = this.scope('JOB', 'book_id', bookId);
    await this.store.update(values, predicates);
  }

  async jobs(): Promise<JobRow[]> {
    if (this.store === null) {
      return [];
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('JOB');
    predicates.equalTo('server', this.server);
    predicates.orderByDesc('at');
    const result: relationalStore.ResultSet = await this.store.query(predicates);
    const rows: JobRow[] = [];
    while (result.goToNextRow()) {
      rows.push({
        bookId: text(result.getValue(result.getColumnIndex('book_id'))),
        title: text(result.getValue(result.getColumnIndex('title'))),
        profile: text(result.getValue(result.getColumnIndex('profile'))),
        state: text(result.getValue(result.getColumnIndex('state'))),
        total: count(result.getValue(result.getColumnIndex('total'))),
        done: count(result.getValue(result.getColumnIndex('done'))),
        bytes: count(result.getValue(result.getColumnIndex('bytes'))),
        pages: count(result.getValue(result.getColumnIndex('pages'))),
        size: count(result.getValue(result.getColumnIndex('size'))),
        at: count(result.getValue(result.getColumnIndex('at'))),
        msg: text(result.getValue(result.getColumnIndex('msg')))
      });
    }
    result.close();
    return rows;
  }

  async removeJob(bookId: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    const predicates: relationalStore.RdbPredicates = this.scope('JOB', 'book_id', bookId);
    await this.store.delete(predicates);
  }

  async saveBook(book: OfflineBookRow): Promise<void> {
    if (this.store === null) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      'server': this.server,
      'book_id': book.bookId,
      'title': book.title,
      'profile': book.profile,
      'items': book.items,
      'bytes': book.bytes,
      'at': book.at
    };
    await this.store.insert('OFFLINE_BOOK', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  async books(): Promise<OfflineBookRow[]> {
    if (this.store === null) {
      return [];
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('OFFLINE_BOOK');
    predicates.equalTo('server', this.server);
    predicates.orderByDesc('at');
    const result: relationalStore.ResultSet = await this.store.query(predicates);
    const rows: OfflineBookRow[] = [];
    while (result.goToNextRow()) {
      rows.push({
        bookId: text(result.getValue(result.getColumnIndex('book_id'))),
        title: text(result.getValue(result.getColumnIndex('title'))),
        profile: text(result.getValue(result.getColumnIndex('profile'))),
        items: count(result.getValue(result.getColumnIndex('items'))),
        bytes: count(result.getValue(result.getColumnIndex('bytes'))),
        at: count(result.getValue(result.getColumnIndex('at')))
      });
    }
    result.close();
    return rows;
  }

  async removeBook(bookId: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    const predicates: relationalStore.RdbPredicates = this.scope('OFFLINE_BOOK', 'book_id', bookId);
    await this.store.delete(predicates);
  }

  async queue(method: string, path: string, body: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      'server': this.server,
      'method': method,
      'path': path,
      'body': body,
      'at': Date.now()
    };
    await this.store.insert('PROGRESS_OUTBOX', values);
  }

  async outbox(): Promise<OutboxRow[]> {
    if (this.store === null) {
      return [];
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('PROGRESS_OUTBOX');
    predicates.equalTo('server', this.server);
    predicates.orderByAsc('id');
    predicates.limitAs(200);
    const result: relationalStore.ResultSet = await this.store.query(predicates);
    const rows: OutboxRow[] = [];
    while (result.goToNextRow()) {
      rows.push({
        id: count(result.getValue(result.getColumnIndex('id'))),
        method: text(result.getValue(result.getColumnIndex('method'))),
        path: text(result.getValue(result.getColumnIndex('path'))),
        body: text(result.getValue(result.getColumnIndex('body'))),
        at: count(result.getValue(result.getColumnIndex('at')))
      });
    }
    result.close();
    return rows;
  }

  async dropOutbox(id: number): Promise<void> {
    if (this.store === null) {
      return;
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('PROGRESS_OUTBOX');
    predicates.equalTo('id', id);
    await this.store.delete(predicates);
  }

  async outboxAll(): Promise<OutboxRow[]> {
    if (this.store === null) {
      return [];
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('PROGRESS_OUTBOX');
    predicates.equalTo('server', this.server);
    predicates.orderByAsc('id');
    const result: relationalStore.ResultSet = await this.store.query(predicates);
    const rows: OutboxRow[] = [];
    while (result.goToNextRow()) {
      rows.push({
        id: count(result.getValue(result.getColumnIndex('id'))),
        method: text(result.getValue(result.getColumnIndex('method'))),
        path: text(result.getValue(result.getColumnIndex('path'))),
        body: text(result.getValue(result.getColumnIndex('body'))),
        at: count(result.getValue(result.getColumnIndex('at')))
      });
    }
    result.close();
    return rows;
  }

  async dropOutboxByBook(bookId: string): Promise<number> {
    if (this.store === null || bookId.length === 0) {
      return 0;
    }
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('PROGRESS_OUTBOX');
      predicates.equalTo('server', this.server);
      predicates.like('path', `%/books/${bookId}/%`);
      return await this.store.delete(predicates);
    } catch (error) {
      return 0;
    }
  }

  async outboxCount(): Promise<number> {
    if (this.store === null) {
      return 0;
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('PROGRESS_OUTBOX');
    predicates.equalTo('server', this.server);
    const result: relationalStore.ResultSet = await this.store.query(predicates, ['id']);
    const total: number = result.rowCount;
    result.close();
    return total < 0 ? 0 : total;
  }

  async saveReading(row: ReadingRow): Promise<void> {
    if (this.store === null) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      'server': this.server,
      'client_id': row.clientId,
      'book_id': row.bookId,
      'started_at': row.startedAt,
      'ended_at': row.endedAt,
      'duration_ms': row.durationMs,
      'start_page': row.startPage,
      'last_page': row.lastPage,
      'pages_read': row.pagesRead,
      'state': row.state,
      'retry': row.retry,
      'at': row.at
    };
    await this.store.insert('READING_SESSION', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  async openReading(): Promise<ReadingRow | null> {
    if (this.store === null) {
      return null;
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('READING_SESSION');
    predicates.equalTo('server', this.server);
    predicates.equalTo('state', 'open');
    predicates.orderByDesc('at');
    predicates.limitAs(1);
    const result: relationalStore.ResultSet = await this.store.query(predicates);
    let row: ReadingRow | null = null;
    if (result.goToNextRow()) {
      row = this.readingFrom(result);
    }
    result.close();
    return row;
  }

  async pendingReadings(limit: number): Promise<ReadingRow[]> {
    if (this.store === null) {
      return [];
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('READING_SESSION');
    predicates.equalTo('server', this.server);
    predicates.equalTo('state', 'pending');
    predicates.orderByAsc('at');
    predicates.limitAs(limit);
    const result: relationalStore.ResultSet = await this.store.query(predicates);
    const rows: ReadingRow[] = [];
    while (result.goToNextRow()) {
      rows.push(this.readingFrom(result));
    }
    result.close();
    return rows;
  }

  async pendingReadingCount(): Promise<number> {
    return await this.countWhere('READING_SESSION', 'pending');
  }

  async readingBookIds(): Promise<string[]> {
    const out: string[] = [];
    if (this.store === null) {
      return out;
    }
    try {
      const result: relationalStore.ResultSet = await this.store.querySql(
        'SELECT DISTINCT book_id FROM READING_SESSION WHERE server = ?', [this.server]);
      const index: number = result.getColumnIndex('book_id');
      while (result.goToNextRow()) {
        const id: string = text(result.getValue(index));
        if (id.length > 0) {
          out.push(id);
        }
      }
      result.close();
    } catch (error) {
    }
    return out;
  }

  async dropReadingsByBook(bookId: string): Promise<number> {
    if (this.store === null) {
      return 0;
    }
    const predicates: relationalStore.RdbPredicates = this.scope('READING_SESSION', 'book_id', bookId);
    return await this.store.delete(predicates);
  }

  private async countWhere(table: string, state: string): Promise<number> {
    if (this.store === null) {
      return 0;
    }
    try {
      const result: relationalStore.ResultSet = await this.store.querySql(
        `SELECT COUNT(*) AS total FROM ${table} WHERE server = ? AND state = ?`, [this.server, state]);
      let total: number = 0;
      if (result.goToNextRow()) {
        total = count(result.getValue(result.getColumnIndex('total')));
      }
      result.close();
      return total;
    } catch (error) {
      return 0;
    }
  }

  async dropReading(clientId: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    const predicates: relationalStore.RdbPredicates = this.scope('READING_SESSION', 'client_id', clientId);
    await this.store.delete(predicates);
  }

  async bumpReading(clientId: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    const args: relationalStore.ValueType[] = [clientId, this.server];
    await this.store.executeSql(
      'UPDATE READING_SESSION SET retry = retry + 1 WHERE client_id = ? AND server = ?', args);
  }

  async saveLocal(meta: LocalMeta, root: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    await this.store.insert('LOCAL_BOOK', this.localValues(meta, root),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  async saveLocals(metas: LocalMeta[], root: string): Promise<void> {
    if (this.store === null || metas.length === 0) {
      return;
    }
    try {
      this.store.beginTransaction();
      for (let index: number = 0; index < metas.length; index++) {
        await this.store.insert('LOCAL_BOOK', this.localValues(metas[index], root),
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      }
      this.store.commit();
    } catch (error) {
      try {
        this.store.rollBack();
      } catch (inner) {
      }
    }
  }

  async locals(): Promise<LocalMeta[]> {
    if (this.store === null) {
      return [];
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('LOCAL_BOOK');
    predicates.orderByDesc('at');
    const result: relationalStore.ResultSet = await this.store.query(predicates);
    const rows: LocalMeta[] = [];
    while (result.goToNextRow()) {
      rows.push({
        id: text(result.getValue(result.getColumnIndex('local_id'))),
        uri: text(result.getValue(result.getColumnIndex('uri'))),
        name: text(result.getValue(result.getColumnIndex('name'))),
        title: text(result.getValue(result.getColumnIndex('title'))),
        author: text(result.getValue(result.getColumnIndex('author'))),
        series: text(result.getValue(result.getColumnIndex('series'))),
        publisher: text(result.getValue(result.getColumnIndex('publisher'))),
        date: text(result.getValue(result.getColumnIndex('date'))),
        profile: text(result.getValue(result.getColumnIndex('profile'))),
        pages: count(result.getValue(result.getColumnIndex('pages'))),
        sizeBytes: count(result.getValue(result.getColumnIndex('size'))),
        cover: text(result.getValue(result.getColumnIndex('cover'))),
        kind: text(result.getValue(result.getColumnIndex('kind'))),
        chapter: count(result.getValue(result.getColumnIndex('chapter'))),
        progress: count(result.getValue(result.getColumnIndex('progress')))
      });
    }
    result.close();
    return rows;
  }

  async patchLocalProgress(localId: string, chapter: number, progress: number): Promise<void> {
    if (this.store === null) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      'chapter': chapter,
      'progress': progress
    };
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('LOCAL_BOOK');
    predicates.equalTo('local_id', localId);
    await this.store.update(values, predicates);
  }

  async removeLocal(localId: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('LOCAL_BOOK');
    predicates.equalTo('local_id', localId);
    await this.store.delete(predicates);
  }

  async clearLocals(): Promise<void> {
    if (this.store === null) {
      return;
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('LOCAL_BOOK');
    await this.store.delete(predicates);
  }

  private localValues(meta: LocalMeta, root: string): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
      'local_id': meta.id,
      'uri': meta.uri,
      'name': meta.name,
      'size': meta.sizeBytes,
      'title': meta.title,
      'author': meta.author,
      'series': meta.series,
      'publisher': meta.publisher,
      'date': meta.date,
      'profile': meta.profile,
      'pages': meta.pages,
      'kind': meta.kind,
      'cover': meta.cover,
      'root': root,
      'at': Date.now(),
      'chapter': meta.chapter,
      'progress': meta.progress
    };
    return values;
  }

  private scope(table: string, column: string, value: string): relationalStore.RdbPredicates {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(table);
    predicates.equalTo('server', this.server);
    predicates.equalTo(column, value);
    return predicates;
  }

  private readingFrom(result: relationalStore.ResultSet): ReadingRow {
    return {
      clientId: text(result.getValue(result.getColumnIndex('client_id'))),
      bookId: text(result.getValue(result.getColumnIndex('book_id'))),
      startedAt: text(result.getValue(result.getColumnIndex('started_at'))),
      endedAt: text(result.getValue(result.getColumnIndex('ended_at'))),
      durationMs: count(result.getValue(result.getColumnIndex('duration_ms'))),
      startPage: count(result.getValue(result.getColumnIndex('start_page'))),
      lastPage: count(result.getValue(result.getColumnIndex('last_page'))),
      pagesRead: count(result.getValue(result.getColumnIndex('pages_read'))),
      state: text(result.getValue(result.getColumnIndex('state'))),
      retry: count(result.getValue(result.getColumnIndex('retry'))),
      at: count(result.getValue(result.getColumnIndex('at')))
    };
  }
}

export const offlineDb: OfflineDb = new OfflineDb();
