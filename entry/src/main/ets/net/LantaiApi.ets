import { LantaiSession, SessionResponse } from './LantaiSession';
import { J } from '../common/Json';
import { t } from '../common/I18n';
import {
  AnnotationMapper,
  BookAnnotation,
  BookItem,
  BookMapper,
  BookPage,
  BookQuery,
  ChapterMapper,
  ChapterPage,
  CollectionCard,
  HomePayload,
  LibraryRef,
  ReadListMapper,
  ReadListRef,
  ReadListSummary,
  ReadingStats,
  SeriesCard,
  SeriesItem,
  SeriesMapper,
  SeriesPage,
  StatsMapper,
  UserProfile,
  UserProfileMapper
} from '../model/LantaiModels';

interface OpCond {
  operator: string;
  value: string;
}

interface MediaProfileCond {
  mediaProfile: OpCond;
}

interface ReadStatusCond {
  readStatus: OpCond;
}

interface LibraryCond {
  libraryId: OpCond;
}

interface ReadListCond {
  readListId: OpCond;
}

interface DateOpCond {
  operator: string;
  dateTime: string;
}

interface ReleaseDateCond {
  releaseDate: DateOpCond;
}

interface BookSeriesFilterBody {
  seriesStatus?: string;
  firstLetter?: string;
}

interface BookSeriesFilterCond {
  bookSeriesFilter: BookSeriesFilterBody;
}

interface AllOfCond {
  allOf: Object[];
}

interface BookSearchBody {
  condition?: AllOfCond;
  fullTextSearch?: string;
}

export class ApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

function firstAuthor(item: Record<string, Object>): string {
  const agg: Record<string, Object> = J.obj(item, 'booksMetadata');
  const raw: Object[] = J.list(agg, 'authors');
  for (let index: number = 0; index < raw.length; index++) {
    const author: Record<string, Object> = raw[index] as Record<string, Object>;
    const name: string = J.str(author, 'name');
    if (name.length > 0) {
      return name;
    }
  }
  return '';
}

export class LantaiApi {
  private session: LantaiSession;

  constructor(session: LantaiSession) {
    this.session = session;
  }

  async home(limit: number): Promise<HomePayload> {
    const response: SessionResponse = await this.session.fetch(`/api/lantai/v1/app/home?limit=${limit}`);
    this.expect(response, t('首页'));
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    const counts: Record<string, Object> = J.obj(body, 'counts');
    const counter: Record<string, number> = {};
    const keys: string[] = ['continueReading', 'added', 'published', 'recentRead', 'newSeries', 'updatedSeries'];
    for (let index = 0; index < keys.length; index++) {
      counter[keys[index]] = J.num(counts, keys[index]);
    }
    const libraries: LibraryRef[] = [];
    const rawLibraries: Object[] = J.list(body, 'libraries');
    for (let index = 0; index < rawLibraries.length; index++) {
      const lib: Record<string, Object> = rawLibraries[index] as Record<string, Object>;
      const ref: LibraryRef = { id: J.str(lib, 'id'), name: J.str(lib, 'name') };
      libraries.push(ref);
    }
    return {
      counts: counter,
      libraries: libraries,
      continueReading: BookMapper.listOf(J.list(body, 'continueReading')),
      added: BookMapper.listOf(J.list(body, 'added')),
      published: BookMapper.listOf(J.list(body, 'published')),
      recentRead: BookMapper.listOf(J.list(body, 'recentRead')),
      newSeries: BookMapper.seriesOf(J.list(body, 'newSeries')),
      updatedSeries: BookMapper.seriesOf(J.list(body, 'updatedSeries')),
      generatedAt: J.str(body, 'generatedAt')
    };
  }

  async books(query: BookQuery): Promise<BookPage> {
    const body: BookSearchBody = {};
    const conditions: Object[] = [];
    if (query.profile.length > 0) {
      const op: OpCond = { operator: 'is', value: query.profile };
      const cond: MediaProfileCond = { mediaProfile: op };
      conditions.push(cond);
    }
    if (query.readState.length > 0) {
      const op: OpCond = { operator: 'is', value: query.readState };
      const cond: ReadStatusCond = { readStatus: op };
      conditions.push(cond);
    }
    if (query.libraryId.length > 0) {
      const op: OpCond = { operator: 'is', value: query.libraryId };
      const cond: LibraryCond = { libraryId: op };
      conditions.push(cond);
    }
    if (query.readListId.length > 0) {
      const op: OpCond = { operator: 'is', value: query.readListId };
      const cond: ReadListCond = { readListId: op };
      conditions.push(cond);
    }
  const filter: BookSeriesFilterBody = {};
    if (query.serial.length > 0) {
      filter.seriesStatus = query.serial;
    }
    if (query.letter.length > 0) {
      filter.firstLetter = query.letter;
    }
    if (query.serial.length > 0 || query.letter.length > 0) {
      const cond: BookSeriesFilterCond = { bookSeriesFilter: filter };
      conditions.push(cond);
    }
    if (query.year.length > 0) {
      const year: number = parseInt(query.year, 10);
      let label: string = `${year}`;
      while (label.length < 4) {
        label = `0${label}`;
      }
      const after: DateOpCond = { operator: 'after', dateTime: `${label}-01-01T00:00:00Z` };
      const before: DateOpCond = { operator: 'before', dateTime: `${label}-12-31T23:59:59Z` };
      const lower: ReleaseDateCond = { releaseDate: after };
      const upper: ReleaseDateCond = { releaseDate: before };
      conditions.push(lower);
      conditions.push(upper);
    }
    if (conditions.length > 0) {
      const all: AllOfCond = { allOf: conditions };
      body.condition = all;
    }
    if (query.text.length > 0) {
      body.fullTextSearch = query.text;
    }
    let path: string = `/api/v1/books/list?page=${query.page}&size=${query.size}&readerView=true`;
    if (query.sort.length > 0) {
      path += `&sort=${query.sort}`;
    }
    const response: SessionResponse = await this.session.postJson(path, JSON.stringify(body));
    this.expect(response, t('书库'));
    return this.toPage(this.session.decodeText(response.bytes), query);
  }

  async facetYears(): Promise<string[]> {
    const response: SessionResponse = await this.session.fetch('/api/lantai/v1/catalog/facets');
    this.expect(response, t('年份分布'));
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    const raw: Object[] = J.list(body, 'years');
    const out: string[] = [];
    for (let index: number = 0; index < raw.length; index++) {
      const value: string = J.str(raw[index] as Record<string, Object>, 'value');
      if (value.length === 4) {
        out.push(value);
      }
    }
    return out;
  }

  async book(id: string): Promise<BookItem> {
    const response: SessionResponse = await this.session.fetch(`/api/v1/books/${id}`);
    this.expect(response, t('书籍详情'));
    return BookMapper.fromDto(J.parse(this.session.decodeText(response.bytes)));
  }

  async booksMissing(ids: string[]): Promise<string[]> {
    const response: SessionResponse = await this.session.postJson(
      '/api/lantai/v1/app/books/existence', JSON.stringify({ ids: ids }));
    this.expect(response, t('书籍检测'));
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    return J.strList(body, 'missing');
  }

  async series(id: string): Promise<SeriesItem> {
    const response: SessionResponse = await this.session.fetch(`/api/v1/series/${id}`);
    this.expect(response, t('系列详情'));
    return SeriesMapper.fromDto(J.parse(this.session.decodeText(response.bytes)));
  }

  async seriesPage(page: number, size: number, sort: string): Promise<SeriesPage> {
    const response: SessionResponse = await this.session.postJson(
      `/api/v1/series/list?page=${page}&size=${size}&sort=${sort}&readerView=true`, JSON.stringify({}));
    this.expect(response, t('系列列表'));
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    const raw: Object[] = J.list(body, 'content');
    const out: SeriesCard[] = [];
    for (let index = 0; index < raw.length; index++) {
      const item: Record<string, Object> = raw[index] as Record<string, Object>;
      const metadata: Record<string, Object> = J.obj(item, 'metadata');
      const title: string = J.str(metadata, 'title');
      const name: string = J.str(item, 'name');
      out.push({
        id: J.str(item, 'id'),
        title: title.length > 0 ? title : name,
        books: J.num(item, 'booksCount'),
        read: J.num(item, 'booksReadCount'),
        reading: J.num(item, 'booksInProgressCount'),
        at: J.str(item, 'lastModified'),
        author: firstAuthor(item)
      });
    }
    return { items: out, total: J.num(body, 'totalElements') };
  }

  async seriesCover(id: string): Promise<ArrayBuffer> {
    const response: SessionResponse = await this.session.fetch(`/api/v1/series/${id}/thumbnail`);
    if (response.status !== 200) {
      throw new ApiError(response.status, t(`封面 HTTP ${response.status}`));
    }
    return response.bytes;
  }

  async seriesStats(): Promise<SeriesCard[]> {
    const response: SessionResponse = await this.session.postJson(
      '/api/v1/series/list?page=0&size=500&sort=lastModified,desc&readerView=true', JSON.stringify({}));
    this.expect(response, t('系列统计'));
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    const raw: Object[] = J.list(body, 'content');
    const out: SeriesCard[] = [];
    for (let index = 0; index < raw.length; index++) {
      const item: Record<string, Object> = raw[index] as Record<string, Object>;
      out.push({
        id: J.str(item, 'id'),
        title: '',
        books: J.num(item, 'booksCount'),
        read: J.num(item, 'booksReadCount'),
        reading: J.num(item, 'booksInProgressCount'),
        at: '',
        author: ''
      });
    }
    return out;
  }

  async seriesBooks(id: string): Promise<BookItem[]> {
    const response: SessionResponse = await this.session.fetch(
      `/api/v1/series/${id}/books?page=0&size=2000&sort=metadata.numberSort,asc`);
    this.expect(response, t('系列分册'));
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    const raw: Object[] = J.list(body, 'content');
    const out: BookItem[] = [];
    for (let index = 0; index < raw.length; index++) {
      out.push(BookMapper.fromDto(raw[index] as Record<string, Object>));
    }
    return out;
  }

  async collections(): Promise<CollectionCard[]> {
    const response: SessionResponse = await this.session.fetch('/api/v1/collections?size=100&sort=name,asc');
    this.expect(response, t('系列合集'));
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    const raw: Object[] = J.list(body, 'content');
    const out: CollectionCard[] = [];
    for (let index = 0; index < raw.length; index++) {
      const item: Record<string, Object> = raw[index] as Record<string, Object>;
      out.push({
        id: J.str(item, 'id'),
        name: J.str(item, 'name'),
        seriesCount: J.strList(item, 'seriesIds').length,
        seriesIds: J.strList(item, 'seriesIds'),
        at: J.str(item, 'lastModifiedDate')
      });
    }
    return out;
  }

  async collectionFirstSeries(id: string): Promise<string> {
    const response: SessionResponse = await this.session.fetch(
      `/api/v1/collections/${id}/series?page=0&size=1`);
    if (response.status !== 200) {
      return '';
    }
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    const raw: Object[] = J.list(body, 'content');
    return raw.length > 0 ? J.str(raw[0] as Record<string, Object>, 'id') : '';
  }

  private jsonArray(items: string[]): string {
    let out: string = '[';
    for (let index = 0; index < items.length; index++) {
      out += (index > 0 ? ',' : '') + JSON.stringify(items[index]);
    }
    return `${out}]`;
  }

  async createCollection(name: string, seriesIds: string[]): Promise<void> {
    const body: string =
      `{"name":${JSON.stringify(name)},"ordered":false,"seriesIds":${this.jsonArray(seriesIds)}}`;
    const status: number = await this.session.sendJson('POST', '/api/v1/collections', body);
    if (status < 200 || status >= 300) {
      throw new ApiError(status, t(`新建系列合集 HTTP ${status}`));
    }
  }

  async updateCollectionSeries(id: string, seriesIds: string[]): Promise<void> {
    const body: string = `{"seriesIds":${this.jsonArray(seriesIds)}}`;
    const status: number = await this.session.sendJson('PATCH', `/api/v1/collections/${id}`, body);
    if (status < 200 || status >= 300) {
      throw new ApiError(status, t(`加入系列合集 HTTP ${status}`));
    }
  }

  async createReadList(name: string, bookIds: string[]): Promise<void> {
    const body: string =
      `{"name":${JSON.stringify(name)},"summary":"","ordered":true,"bookIds":${this.jsonArray(bookIds)}}`;
    const status: number = await this.session.sendJson('POST', '/api/v1/readlists', body);
    if (status < 200 || status >= 300) {
      throw new ApiError(status, t(`新建书单 HTTP ${status}`));
    }
  }

  async updateReadListBooks(id: string, bookIds: string[]): Promise<void> {
    const body: string = `{"bookIds":${this.jsonArray(bookIds)}}`;
    const status: number = await this.session.sendJson('PATCH', `/api/v1/readlists/${id}`, body);
    if (status < 200 || status >= 300) {
      throw new ApiError(status, t(`加入书单 HTTP ${status}`));
    }
  }

  async chapters(id: string): Promise<ChapterPage> {
    const response: SessionResponse = await this.session.fetch(
      `/api/lantai/v1/read/${id}/chapters?outline=true`);
    this.expect(response, t('目录'));
    return ChapterMapper.fromDto(J.parse(this.session.decodeText(response.bytes)));
  }

  async capabilities(): Promise<string[]> {
    const response: SessionResponse = await this.session.fetch('/api/lantai/v1/reading/capabilities');
    this.expect(response, t('服务能力'));
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    const out: string[] = [];
    out.push(J.bool(body, 'heartbeat') ? t('阅读会话心跳 · 支持') : t('阅读会话心跳 · 不支持'));
    out.push(J.bool(body, 'offlineSync') ? t('离线会话补报 · 支持') : t('离线会话补报 · 不支持'));
    out.push(t(`阅读接口版本 · ${J.num(body, 'apiVersion')}`));
    return out;
  }

  async readingStats(): Promise<ReadingStats> {
    const response: SessionResponse = await this.session.fetch('/api/lantai/v1/reading/stats');
    this.expect(response, t('阅读统计'));
    return StatsMapper.fromDto(J.parse(this.session.decodeText(response.bytes)));
  }

  async readlistsOfBook(id: string): Promise<ReadListRef[]> {
    const response: SessionResponse = await this.session.fetch(
      `/api/v1/readlists?unpaged=true&bookId=${encodeURIComponent(id)}`);
    if (response.status !== 200) {
      return [];
    }
    return ReadListMapper.ofBook(J.parse(this.session.decodeText(response.bytes)), id);
  }

  async readlists(): Promise<ReadListSummary[]> {
    const response: SessionResponse = await this.session.fetch('/api/v1/readlists?size=100&sort=lastModifiedDate,desc');
    this.expect(response, t('书单'));
    return ReadListMapper.summaries(J.parse(this.session.decodeText(response.bytes)));
  }

  async annotations(bookId: string): Promise<BookAnnotation[]> {
    const response: SessionResponse = await this.session.fetch(`/api/lantai/v1/annotations?bookId=${bookId}`);
    if (response.status !== 200) {
      throw new ApiError(response.status, t(`批注 HTTP ${response.status}`));
    }
    return AnnotationMapper.listOf(J.arrayOf(this.session.decodeText(response.bytes)));
  }

  async wantToReadState(bookId: string): Promise<boolean> {
    const response: SessionResponse = await this.session.fetch(`/api/lantai/v1/want-to-read/book/${bookId}`);
    if (response.status !== 200) {
      return false;
    }
    return J.bool(J.parse(this.session.decodeText(response.bytes)), 'wanted');
  }

  async setWantToRead(bookId: string, wanted: boolean): Promise<void> {
    const status: number = await this.session.sendJson(wanted ? 'POST' : 'DELETE',
      `/api/lantai/v1/want-to-read/book/${bookId}`, wanted ? '{}' : null);
    if (status < 200 || status >= 300) {
      throw new ApiError(status, t(`待读 HTTP ${status}`));
    }
  }

  async wantToRead(page: number, size: number): Promise<BookPage> {
    const response: SessionResponse = await this.session.fetch(
      `/api/lantai/v1/want-to-read?page=${page}&size=${size}`);
    this.expect(response, t('待读'));
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    const raw: Object[] = J.list(body, 'items');
    const items: BookItem[] = [];
    for (let index = 0; index < raw.length; index++) {
      items.push(BookMapper.fromDto(raw[index] as Record<string, Object>));
    }
    return {
      items: items,
      total: J.num(body, 'total'),
      page: J.num(body, 'page'),
      size: J.num(body, 'size'),
      pages: 0
    };
  }

  async markRead(bookId: string, completed: boolean): Promise<void> {
    const status: number = completed
      ? await this.session.sendJson('PATCH', `/api/v1/books/${bookId}/read-progress`, '{"completed":true}')
      : await this.session.sendJson('DELETE', `/api/v1/books/${bookId}/read-progress`, null);
    if (status < 200 || status >= 300) {
      throw new ApiError(status, completed ? t(`标记已读 HTTP ${status}`) : t(`标记未读 HTTP ${status}`));
    }
  }

  async page(id: string, n: number, convert: string, width: number = 0): Promise<ArrayBuffer> {
    const wide: string = width > 0 ? `&w=${width}` : '';
    const response: SessionResponse = await this.session.fetch(
      `/api/v1/books/${id}/pages/${n}?convert=${convert}${wide}`, 'image/jpeg', 64 * 1024 * 1024);
    if (response.status !== 200) {
      throw new ApiError(response.status, t(`页图 HTTP ${response.status} · ${response.bytes.byteLength} B`));
    }
    const type: string = response.contentType.toLowerCase();
    if (type.length > 0 && type.indexOf('image/') !== 0) {
      throw new ApiError(response.status, t(`页图格式异常 ${response.contentType}`));
    }
    if (response.bytes.byteLength === 0) {
      throw new ApiError(response.status, t('页图为空'));
    }
    return response.bytes;
  }

  async savePage(bookId: string, page: number): Promise<void> {
    if (page <= 0) {
      return;
    }
    const status: number = await this.session.sendJson(
      'PATCH', `/api/v1/books/${bookId}/read-progress`, JSON.stringify({ page: page }));
    if (status >= 400) {
      throw new ApiError(status, t(`记录进度 HTTP ${status}`));
    }
  }

  async pageThumb(id: string, n: number): Promise<ArrayBuffer> {
    const response: SessionResponse = await this.session.fetch(
      `/api/v1/books/${id}/pages/${n}/thumbnail`, 'image/jpeg', 4 * 1024 * 1024);
    if (response.status !== 200) {
      throw new ApiError(response.status, t(`缩略图 HTTP ${response.status}`));
    }
    if (response.bytes.byteLength === 0) {
      throw new ApiError(response.status, t('缩略图为空'));
    }
    return response.bytes;
  }

  async cover(id: string, width: number): Promise<ArrayBuffer> {
    const response: SessionResponse = await this.session.fetch(
      `/api/lantai/v1/app/cover/${id}?w=${width}&fmt=jpeg`);
    if (response.status !== 200) {
      throw new ApiError(response.status, t(`封面 HTTP ${response.status}`));
    }
    return response.bytes;
  }

  async me(): Promise<string> {
    const response: SessionResponse = await this.session.fetch('/api/v2/users/me');
    if (response.status !== 200) {
      return '';
    }
    const body: Record<string, Object> = J.parse(this.session.decodeText(response.bytes));
    const name: string = J.str(body, 'username');
    if (name.length > 0) {
      return name;
    }
    const mail: string = J.str(body, 'email');
    return mail.length > 0 ? mail : t('已连接');
  }

  async userProfile(): Promise<UserProfile> {
    const response: SessionResponse = await this.session.fetch('/api/lantai/v1/user-profile/me');
    if (response.status !== 200) {
      throw new ApiError(response.status, t(`用户资料 HTTP ${response.status}`));
    }
    return UserProfileMapper.of(J.parse(this.session.decodeText(response.bytes)));
  }

  async userAvatar(userId: string): Promise<ArrayBuffer> {
    const response: SessionResponse = await this.session.fetch(
      `/api/lantai/v1/user-profile/${userId}/avatar`, 'image/png');
    if (response.status !== 200) {
      throw new ApiError(response.status, t(`头像 HTTP ${response.status}`));
    }
    const type: string = response.contentType.toLowerCase();
    if (type.length > 0 && type.indexOf('image/') !== 0) {
      throw new ApiError(response.status, t(`头像格式异常 ${response.contentType}`));
    }
    return response.bytes;
  }

  private toPage(text: string, query: BookQuery): BookPage {
    const body: Record<string, Object> = J.parse(text);
    const raw: Object[] = J.list(body, 'content');
    const items: BookItem[] = [];
    for (let index = 0; index < raw.length; index++) {
      items.push(BookMapper.fromDto(raw[index] as Record<string, Object>));
    }
    return {
      items: items,
      total: J.num(body, 'totalElements'),
      page: J.num(body, 'number'),
      size: J.num(body, 'size'),
      pages: J.num(body, 'totalPages')
    };
  }

  private expect(response: SessionResponse, label: string): void {
    if (response.status === 200) {
      return;
    }
    if (response.status === 401) {
      throw new ApiError(401, t('会话已过期'));
    }
    const text: string = this.session.decodeText(response.bytes);
    let message: string = `${label} HTTP ${response.status}`;
    try {
      const body: Record<string, Object> = J.parse(text);
      const detail: string = J.str(body, 'message');
      if (detail.length > 0) {
        message = detail;
      }
    } catch (error) {
      if (text.length > 0 && text.length < 200) {
        message = text;
      }
    }
    throw new ApiError(response.status, message);
  }
}
