import { J } from '../common/Json';

import { t } from '../common/I18n';
export interface BookItem {
  id: string;
  title: string;
  seriesId: string;
  seriesTitle: string;
  number: string;
  volume: string;
  profile: string;
  pages: number;
  size: string;
  sizeBytes: number;
  authors: string;
  summary: string;
  tags: string[];
  created: string;
  lastModified: string;
  readPage: number;
  readCompleted: boolean;
  readDate: string;
  readState: string;
  fileName: string;
  filePath: string;
  fileHash: string;
  fileModified: string;
  mediaType: string;
  mediaStatus: string;
  publisher: string;
  isbn: string;
  language: string;
  genres: string[];
  releaseDate: string;
  metaUpdated: string;
  numberSort: number;
  notableCount: number;
  lockedCount: number;
  linkCount: number;
  oneshot: boolean;
}

export interface ChapterItem {
  n: number;
  title: string;
  depth: number;
  chars: number;
}

export interface ChapterPage {
  chapters: number;
  total: number;
  from: number;
  to: number;
  items: ChapterItem[];
}

export interface DayStat {
  date: string;
  durationMs: number;
  pagesRead: number;
  sessionCount: number;
}

export interface BookStat {
  bookId: string;
  durationMs: number;
  pagesRead: number;
  sessionCount: number;
  lastReadAt: string;
}

export interface ReadingStats {
  from: string;
  to: string;
  totalDurationMs: number;
  totalPagesRead: number;
  sessionCount: number;
  bookCount: number;
  books: BookStat[];
  days: DayStat[];
}

export interface ReadListRef {
  id: string;
  name: string;
}

export interface ReadListSummary {
  id: string;
  name: string;
  summary: string;
  ordered: boolean;
  bookCount: number;
  bookIds: string[];
  lastModified: string;
}

export interface BookAnnotation {
  id: string;
  bookId: string;
  href: string;
  highlight: string;
  color: string;
  marker: string;
  note: string;
  createdDate: string;
}

export interface SeriesItem {
  id: string;
  name: string;
  booksCount: number;
  readCount: number;
  inProgressCount: number;
  summary: string;
  publisher: string;
  language: string;
  genres: string[];
  tags: string[];
  totalBookCount: number;
  status: string;
  created: string;
  lastModified: string;
}

export interface SeriesCard {
  id: string;
  title: string;
  books: number;
  read: number;
  reading: number;
  at: string;
  author: string;
}

export interface SeriesPage {
  items: SeriesCard[];
  total: number;
}

export interface CollectionCard {
  id: string;
  name: string;
  seriesCount: number;
  seriesIds: string[];
  at: string;
}

export interface LibraryRef {
  id: string;
  name: string;
}

export interface HomePayload {
  counts: Record<string, number>;
  libraries: LibraryRef[];
  continueReading: BookItem[];
  added: BookItem[];
  published: BookItem[];
  recentRead: BookItem[];
  newSeries: SeriesCard[];
  updatedSeries: SeriesCard[];
  generatedAt: string;
}

export interface BookPage {
  items: BookItem[];
  total: number;
  page: number;
  size: number;
  pages: number;
}

export interface BookQuery {
  text: string;
  profile: string;
  readState: string;
  libraryId: string;
  readListId: string;
  letter: string;
  serial: string;
  year: string;
  sort: string;
  page: number;
  size: number;
}

export function emptyQuery(): BookQuery {
  return {
    text: '',
    profile: '',
    readState: '',
    libraryId: '',
    readListId: '',
    letter: '',
    serial: '',
    year: '',
    sort: 'metadata.title,asc',
    page: 0,
    size: 24
  };
}

export const PROFILE_EPUB: string = 'EPUB';
export const PROFILE_DIVINA: string = 'DIVINA';
export const PROFILE_PDF: string = 'PDF';
export const PROFILE_IMAGE: string = 'IMAGE';

export function emptyBook(): BookItem {
  return {
    id: '',
    title: '',
    seriesId: '',
    seriesTitle: '',
    number: '',
    volume: '',
    profile: '',
    pages: 0,
    size: '',
    sizeBytes: 0,
    authors: '',
    summary: '',
    tags: [],
    created: '',
    lastModified: '',
    readPage: 0,
    readCompleted: false,
    readDate: '',
    readState: 'UNREAD',
    fileName: '',
    filePath: '',
    fileHash: '',
    fileModified: '',
    mediaType: '',
    mediaStatus: '',
    publisher: '',
    isbn: '',
    language: '',
    genres: [],
    releaseDate: '',
    metaUpdated: '',
    numberSort: 0,
    notableCount: 0,
    lockedCount: 0,
    linkCount: 0,
    oneshot: false
  };
}

export function emptySeries(): SeriesItem {
  return {
    id: '',
    name: '',
    booksCount: 0,
    readCount: 0,
    inProgressCount: 0,
    summary: '',
    publisher: '',
    language: '',
    genres: [],
    tags: [],
    totalBookCount: 0,
    status: '',
    created: '',
    lastModified: ''
  };
}

export function emptyHome(): HomePayload {
  return {
    counts: {},
    libraries: [],
    continueReading: [],
    added: [],
    published: [],
    recentRead: [],
    newSeries: [],
    updatedSeries: [],
    generatedAt: ''
  };
}

export const MEDIA_ERROR: string = 'ERROR';

export function profileLabel(profile: string, status: string = ''): string {
  if (status === MEDIA_ERROR) {
    return t('无法解析');
  }
  if (profile === PROFILE_EPUB) {
    return 'EPUB';
  }
  if (profile === PROFILE_DIVINA) {
    return t('漫画');
  }
  if (profile === PROFILE_PDF) {
    return 'PDF';
  }
  if (profile === PROFILE_IMAGE) {
    return t('图片');
  }
  return profile.length > 0 ? profile : t('未知');
}

export function isEbook(profile: string): boolean {
  return profile === PROFILE_EPUB;
}

export class BookMapper {
  static fromDto(map: Record<string, Object>): BookItem {
    const media: Record<string, Object> = J.obj(map, 'media');
    const metadata: Record<string, Object> = J.obj(map, 'metadata');
    const progress: Record<string, Object> = J.obj(map, 'readProgress');
    const page: number = J.num(progress, 'page');
    const completed: boolean = J.bool(progress, 'completed');
    const title: string = J.str(metadata, 'title');
    return {
      id: J.str(map, 'id'),
      title: title.length > 0 ? title : J.str(map, 'name'),
      seriesId: J.str(map, 'seriesId'),
      seriesTitle: J.str(map, 'seriesTitle'),
      number: J.str(metadata, 'number'),
      volume: J.str(map, 'volume'),
      profile: J.str(media, 'mediaProfile'),
      pages: J.num(media, 'pagesCount'),
      size: J.str(map, 'size'),
      sizeBytes: J.num(map, 'sizeBytes'),
      authors: BookMapper.authorsOf(metadata),
      summary: J.str(metadata, 'summary'),
      tags: J.strList(metadata, 'tags'),
      created: J.str(map, 'created'),
      lastModified: J.str(map, 'lastModified'),
      readPage: page,
      readCompleted: completed,
      readDate: J.str(progress, 'readDate'),
      readState: BookMapper.stateOf(page, completed),
      fileName: J.str(map, 'name'),
      filePath: J.str(map, 'url'),
      fileHash: J.str(map, 'fileHash'),
      fileModified: J.str(map, 'fileLastModified'),
      mediaType: J.str(media, 'mediaType'),
      mediaStatus: J.str(media, 'status'),
      publisher: J.str(metadata, 'publisher'),
      isbn: J.str(metadata, 'isbn'),
      language: J.str(metadata, 'language'),
      genres: J.strList(metadata, 'genres'),
      releaseDate: J.str(metadata, 'releaseDate'),
      metaUpdated: J.str(metadata, 'lastModified'),
      numberSort: J.num(metadata, 'numberSort'),
      notableCount: J.list(metadata, 'notableEntities').length,
      lockedCount: BookMapper.lockedOf(metadata),
      linkCount: J.list(metadata, 'links').length,
      oneshot: J.bool(map, 'oneshot')
    };
  }

  static lockedOf(metadata: Record<string, Object>): number {
    const keys: string[] = Object.keys(metadata);
    let count: number = 0;
    for (let index = 0; index < keys.length; index++) {
      const key: string = keys[index];
      if (key.endsWith('Lock') && J.bool(metadata, key)) {
        count += 1;
      }
    }
    return count;
  }

  static fromHomeCard(map: Record<string, Object>): BookItem {
    const page: number = J.num(map, 'page');
    const completed: boolean = J.bool(map, 'completed');
    return {
      id: J.str(map, 'id'),
      title: J.str(map, 'title'),
      seriesId: J.str(map, 'seriesId'),
      seriesTitle: J.str(map, 'seriesTitle'),
      number: J.str(map, 'number'),
      volume: '',
      profile: J.str(map, 'profile'),
      pages: J.num(map, 'pages'),
      size: '',
      sizeBytes: 0,
      authors: '',
      summary: '',
      tags: [],
      created: '',
      lastModified: '',
      readPage: page,
      readCompleted: completed,
      readDate: J.str(map, 'at'),
      readState: BookMapper.stateOf(page, completed),
      fileName: '',
      filePath: '',
      fileHash: '',
      fileModified: '',
      mediaType: '',
      mediaStatus: '',
      publisher: '',
      isbn: '',
      language: '',
      genres: [],
      releaseDate: '',
      metaUpdated: '',
      numberSort: 0,
      notableCount: 0,
      lockedCount: 0,
      linkCount: 0,
      oneshot: false
    };
  }

  static stateOf(page: number, completed: boolean): string {
    if (completed) {
      return 'READ';
    }
    return page > 0 ? 'IN_PROGRESS' : 'UNREAD';
  }

  static authorsOf(metadata: Record<string, Object>): string {
    const raw: Object[] = J.list(metadata, 'authors');
    const names: string[] = [];
    for (let index = 0; index < raw.length; index++) {
      const name: string = J.str(raw[index] as Record<string, Object>, 'name');
      if (name.length > 0) {
        names.push(name);
      }
    }
    return names.join(' / ');
  }

  static listOf(raw: Object[]): BookItem[] {
    const out: BookItem[] = [];
    for (let index = 0; index < raw.length; index++) {
      out.push(BookMapper.fromHomeCard(raw[index] as Record<string, Object>));
    }
    return out;
  }

  static seriesOf(raw: Object[]): SeriesCard[] {
    const out: SeriesCard[] = [];
    for (let index = 0; index < raw.length; index++) {
      const map: Record<string, Object> = raw[index] as Record<string, Object>;
      out.push({
        id: J.str(map, 'id'),
        title: J.str(map, 'title'),
        books: J.num(map, 'books'),
        read: J.num(map, 'read'),
        reading: J.num(map, 'reading'),
        at: J.str(map, 'at'),
        author: J.str(map, 'author')
      });
    }
    return out;
  }
}

export class ChapterMapper {
  static fromDto(map: Record<string, Object>): ChapterPage {
    const raw: Object[] = J.list(map, 'outline');
    const items: ChapterItem[] = [];
    for (let index = 0; index < raw.length; index++) {
      const item: Record<string, Object> = raw[index] as Record<string, Object>;
      items.push({
        n: J.num(item, 'n'),
        title: J.str(item, 'title'),
        depth: J.num(item, 'depth'),
        chars: J.num(item, 'chars')
      });
    }
    return {
      chapters: J.num(map, 'chapters'),
      total: J.num(map, 'total'),
      from: J.num(map, 'from'),
      to: J.num(map, 'to'),
      items: items
    };
  }
}

export class StatsMapper {
  static fromDto(map: Record<string, Object>): ReadingStats {
    const rawBooks: Object[] = J.list(map, 'books');
    const books: BookStat[] = [];
    for (let index = 0; index < rawBooks.length; index++) {
      const item: Record<string, Object> = rawBooks[index] as Record<string, Object>;
      books.push({
        bookId: J.str(item, 'bookId'),
        durationMs: J.num(item, 'durationMs'),
        pagesRead: J.num(item, 'pagesRead'),
        sessionCount: J.num(item, 'sessionCount'),
        lastReadAt: J.str(item, 'lastReadAt')
      });
    }
    const rawDays: Object[] = J.list(map, 'days');
    const days: DayStat[] = [];
    for (let index = 0; index < rawDays.length; index++) {
      const item: Record<string, Object> = rawDays[index] as Record<string, Object>;
      days.push({
        date: J.str(item, 'date'),
        durationMs: J.num(item, 'durationMs'),
        pagesRead: J.num(item, 'pagesRead'),
        sessionCount: J.num(item, 'sessionCount')
      });
    }
    return {
      from: J.str(map, 'from'),
      to: J.str(map, 'to'),
      totalDurationMs: J.num(map, 'totalDurationMs'),
      totalPagesRead: J.num(map, 'totalPagesRead'),
      sessionCount: J.num(map, 'sessionCount'),
      bookCount: J.num(map, 'bookCount'),
      books: books,
      days: days
    };
  }

  static bookOf(stats: ReadingStats, bookId: string): BookStat | null {
    for (let index = 0; index < stats.books.length; index++) {
      if (stats.books[index].bookId === bookId) {
        return stats.books[index];
      }
    }
    return null;
  }
}

export class SeriesMapper {
  static fromDto(map: Record<string, Object>): SeriesItem {
    const metadata: Record<string, Object> = J.obj(map, 'metadata');
    const title: string = J.str(metadata, 'title');
    const name: string = J.str(map, 'name');
    return {
      id: J.str(map, 'id'),
      name: title.length > 0 ? title : name,
      booksCount: J.num(map, 'booksCount'),
      readCount: J.num(map, 'booksReadCount'),
      inProgressCount: J.num(map, 'booksInProgressCount'),
      summary: J.str(metadata, 'summary'),
      publisher: J.str(metadata, 'publisher'),
      language: J.str(metadata, 'language'),
      genres: J.strList(metadata, 'genres'),
      tags: J.strList(metadata, 'tags'),
      totalBookCount: J.num(metadata, 'totalBookCount'),
      status: J.str(metadata, 'status'),
      created: J.str(map, 'created'),
      lastModified: J.str(map, 'lastModified')
    };
  }
}

export class ReadListMapper {
  static fromPage(map: Record<string, Object>): ReadListRef[] {
    const raw: Object[] = J.list(map, 'content');
    const out: ReadListRef[] = [];
    for (let index = 0; index < raw.length; index++) {
      const item: Record<string, Object> = raw[index] as Record<string, Object>;
      out.push({ id: J.str(item, 'id'), name: J.str(item, 'name') });
    }
    return out;
  }

  static ofBook(map: Record<string, Object>, bookId: string): ReadListRef[] {
    const raw: Object[] = J.list(map, 'content');
    const out: ReadListRef[] = [];
    for (let index = 0; index < raw.length; index++) {
      const item: Record<string, Object> = raw[index] as Record<string, Object>;
      if (J.strList(item, 'bookIds').indexOf(bookId) < 0) {
        continue;
      }
      out.push({ id: J.str(item, 'id'), name: J.str(item, 'name') });
    }
    return out;
  }

  static summaries(map: Record<string, Object>): ReadListSummary[] {
    const raw: Object[] = J.list(map, 'content');
    const out: ReadListSummary[] = [];
    for (let index = 0; index < raw.length; index++) {
      const item: Record<string, Object> = raw[index] as Record<string, Object>;
      out.push({
        id: J.str(item, 'id'),
        name: J.str(item, 'name'),
        summary: J.str(item, 'summary'),
        ordered: J.bool(item, 'ordered'),
        bookCount: J.list(item, 'bookIds').length,
        bookIds: J.strList(item, 'bookIds'),
        lastModified: J.str(item, 'lastModifiedDate')
      });
    }
    return out;
  }
}

export interface UserProfile {
  userId: string;
  username: string;
  nickname: string;
  hasAvatar: boolean;
  avatarUpdated: number;
}

export class UserProfileMapper {
  static of(map: Record<string, Object>): UserProfile {
    const username: string = J.str(map, 'username');
    const nickname: string = J.str(map, 'nickname');
    return {
      userId: J.str(map, 'userId'),
      username: username,
      nickname: nickname.length > 0 ? nickname : username,
      hasAvatar: J.bool(map, 'hasAvatar'),
      avatarUpdated: J.num(map, 'avatarUpdated')
    };
  }
}

export class AnnotationMapper {
  static listOf(raw: Object[]): BookAnnotation[] {
    const out: BookAnnotation[] = [];
    for (let index = 0; index < raw.length; index++) {
      const item: Record<string, Object> = raw[index] as Record<string, Object>;
      out.push({
        id: J.str(item, 'id'),
        bookId: J.str(item, 'bookId'),
        href: J.str(item, 'href'),
        highlight: J.str(item, 'textHighlight'),
        color: J.str(item, 'color'),
        marker: J.str(item, 'marker'),
        note: J.str(item, 'note'),
        createdDate: J.str(item, 'createdDate')
      });
    }
    return out;
  }
}
