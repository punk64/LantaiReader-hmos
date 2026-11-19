import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { pdfService } from '@kit.PDFKit';
import { common } from '@kit.AbilityKit';
import { LocalBook } from './LocalLibrary';
import { ComicArchive } from './ComicArchive';
import { CacheQuota } from './CacheQuota';
import { LocalFiles } from './LocalFiles';
import { ZipBook } from './ZipBook';

export interface LocalMeta {
  id: string;
  uri: string;
  name: string;
  title: string;
  author: string;
  series: string;
  publisher: string;
  date: string;
  profile: string;
  pages: number;
  sizeBytes: number;
  cover: string;
  kind: string;
  chapter: number;
  progress: number;
}

function extensionOf(name: string): string {
  const dot: number = name.lastIndexOf('.');
  return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
}

export function localKindOf(name: string): string {
  const ext: string = extensionOf(name);
  if (ext === 'txt') {
    return 'txt';
  }
  if (ext === 'pdf') {
    return 'pdf';
  }
  if (ext === 'epub' || ext === 'kepub') {
    return 'epub';
  }
  if (ComicArchive.isReadable(name)) {
    return 'comic';
  }
  return '';
}

interface StagedFile {
  file: string;
  dir: string;
}

function hashOf(text: string): string {
  let hash: number = 5381;
  for (let index: number = 0; index < text.length; index++) {
    hash = ((hash << 5) + hash + text.charCodeAt(index)) & 0x7fffffff;
  }
  return hash.toString(36);
}

function attributeOf(tag: string, key: string): string {
  const pattern: RegExp = new RegExp(`${key}\\s*=\\s*"([^"]*)"`);
  const match: RegExpExecArray | null = pattern.exec(tag);
  return match !== null && match.length > 1 ? match[1] : '';
}

function decodeEntities(text: string): string {
  return text.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'").replace(/&amp;/g, '&');
}

function normalizeDir(href: string): string {
  const parts: string[] = href.split('/');
  const out: string[] = [];
  for (let index: number = 0; index < parts.length; index++) {
    const part: string = parts[index];
    if (part === '.' || part.length === 0) {
      continue;
    }
    if (part === '..') {
      if (out.length > 0) {
        out.pop();
      }
      continue;
    }
    out.push(part);
  }
  return out.join('/');
}

function relativeTo(baseDir: string, href: string): string {
  if (href.length > 0 && href.startsWith('/')) {
    return normalizeDir(href.substring(1));
  }
  return normalizeDir(baseDir.length > 0 ? `${baseDir}/${href}` : href);
}

function textOf(xml: string, tag: string): string {
  const pattern: RegExp = new RegExp(`<dc:${tag}[^>]*>([\\s\\S]*?)</dc:${tag}>`);
  const match: RegExpExecArray | null = pattern.exec(xml);
  return match !== null ? decodeEntities(match[1].trim()) : '';
}

const IMAGE_EXT: string[] = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];

export class LocalMetas {
  private base: string = '';
  private static stageDir: string = '';
  private static coverDir: string = '';
  private static rootDir: string = '';
  private static covers: Map<string, string> = new Map<string, string>();
  private static enforceTimer: number = -1;

  init(ctx: common.Context): void {
    if (this.base.length === 0) {
      this.base = `${ctx.filesDir}/local`;
      LocalMetas.stageDir = this.base;
      LocalMetas.coverDir = `${ctx.filesDir}/local-cover`;
      LocalMetas.rootDir = ctx.filesDir;
    }
  }

  static filesRoot(): string {
    return LocalMetas.rootDir;
  }

  static dirOf(uri: string): string {
    return LocalMetas.stageDir.length === 0 ? '' : `${LocalMetas.stageDir}/${hashOf(uri)}`;
  }

  static coverOf(uri: string): string {
    return LocalMetas.coverDir.length === 0 ? '' : `${LocalMetas.coverDir}/${hashOf(uri)}.jpg`;
  }

  static forget(id: string): void {
    LocalMetas.covers.delete(id);
  }

  static coverFile(id: string): string {
    const hit: string | undefined = LocalMetas.covers.get(id);
    if (hit !== undefined && hit.length > 0) {
      return hit;
    }
    if (LocalMetas.coverDir.length === 0 || !id.startsWith('local:')) {
      return '';
    }
    const path: string = LocalMetas.coverPath(id.substring(6));
    return fs.accessSync(path) ? path : '';
  }

  private static coverPath(hash: string): string {
    return `${LocalMetas.coverDir}/${hash}.jpg`;
  }

  static isStableCover(path: string): boolean {
    return LocalMetas.coverDir.length > 0 && path.startsWith(LocalMetas.coverDir);
  }

  private static queueEnforce(): void {
    if (LocalMetas.enforceTimer >= 0) {
      return;
    }
    LocalMetas.enforceTimer = setTimeout(() => {
      LocalMetas.enforceTimer = -1;
      CacheQuota.enforce();
    }, 3000);
  }

  static idOf(uri: string): string {
    return `local:${hashOf(uri)}`;
  }

  static coverPathOf(uri: string, ctx: common.Context): string {
    return `${ctx.filesDir}/local-cover/${hashOf(uri)}.jpg`;
  }

  static seed(book: LocalBook): LocalMeta {
    const meta: LocalMeta = {
      id: LocalMetas.idOf(book.uri),
      uri: book.uri,
      name: book.name,
      title: book.name,
      author: '',
      series: '',
      publisher: '',
      date: '',
      profile: '',
      pages: 0,
      sizeBytes: book.size,
      cover: '',
      kind: '',
      chapter: 0,
      progress: 0
    };
    const dot: number = book.name.lastIndexOf('.');
    if (dot > 0) {
      meta.title = book.name.substring(0, dot);
    }
    if (ComicArchive.isReadable(book.name)) {
      meta.kind = 'comic';
      meta.profile = 'DIVINA';
      return meta;
    }
    const kind: string = localKindOf(book.name);
    meta.kind = kind;
    if (kind === 'epub') {
      meta.profile = 'EPUB';
    } else if (kind === 'pdf') {
      meta.profile = 'PDF';
    } else if (kind === 'txt') {
      meta.profile = 'TXT';
    }
    return meta;
  }

  async enrich(book: LocalBook): Promise<LocalMeta> {
    const meta: LocalMeta = LocalMetas.seed(book);
    if (meta.kind === 'comic') {
      meta.cover = await this.existingCover(book);
      return await this.finish(meta);
    }
    if (this.base.length === 0) {
      return await this.finish(meta);
    }
    try {
      const staged: StagedFile = await this.stage(book.uri, book.name);
      if (meta.kind === 'epub') {
        await this.fillEpub(meta, staged);
      } else if (meta.kind === 'pdf') {
        await this.fillPdf(meta, staged);
      }
    } catch (error) {
    }
    return await this.finish(meta);
  }

  private async finish(meta: LocalMeta): Promise<LocalMeta> {
    if (meta.cover.length > 0 && !LocalMetas.isStableCover(meta.cover)) {
      await this.cacheCover(meta.uri, meta.cover);
      const stable: string = LocalMetas.coverFile(meta.id);
      if (stable.length > 0) {
        meta.cover = stable;
      }
    }
    LocalMetas.covers.set(meta.id, meta.cover);
    return meta;
  }

  async cacheCover(uri: string, imagePath: string): Promise<void> {
    if (LocalMetas.coverDir.length === 0 || imagePath.length === 0) {
      return;
    }
    if (LocalMetas.isStableCover(imagePath)) {
      return;
    }
    const target: string = `${LocalMetas.coverDir}/${hashOf(uri)}.jpg`;
    try {
      if ((await fs.stat(target)).size > 0) {
        return;
      }
    } catch (error) {
    }
    try {
      LocalFiles.ensureDir(LocalMetas.coverDir);
      await fs.copyFile(imagePath, target);
    } catch (error) {
    }
  }

  private async existingCover(book: LocalBook): Promise<string> {
    if (LocalMetas.coverDir.length === 0) {
      return '';
    }
    const stable: string = `${LocalMetas.coverDir}/${hashOf(book.uri)}.jpg`;
    try {
      if ((await fs.stat(stable)).size > 0) {
        return stable;
      }
    } catch (error) {
    }
    const legacy: string = `${this.base}/${hashOf(book.uri)}/cover.jpg`;
    try {
      if ((await fs.stat(legacy)).size > 0) {
        await this.cacheCover(book.uri, legacy);
        if ((await fs.stat(stable)).size > 0) {
          return stable;
        }
      }
    } catch (error) {
    }
    return '';
  }

  private async stage(uri: string, name: string): Promise<StagedFile> {
    const dir: string = `${this.base}/${hashOf(uri)}`;
    const ext: string = extensionOf(name);
    const path: string = `${dir}/book${ext.length > 0 ? '.' + ext : ''}`;
    if (await LocalFiles.exists(path)) {
      CacheQuota.touch(dir);
      LocalMetas.queueEnforce();
      return { file: path, dir: dir };
    }
    await LocalFiles.copyInto(uri, path);
    CacheQuota.touch(dir);
    LocalMetas.queueEnforce();
    return { file: path, dir: dir };
  }

  private async fillEpub(meta: LocalMeta, staged: StagedFile): Promise<void> {
    let book: ZipBook;
    try {
      book = await ZipBook.open(staged.file);
    } catch (error) {
      return;
    }
    const container: string = await book.text('META-INF/container.xml');
    const rootTag: RegExpExecArray | null = /<rootfile\b[^>]*>/.exec(container);
    const opfRel: string = rootTag !== null ? attributeOf(rootTag[0], 'full-path') : '';
    if (opfRel.length === 0) {
      return;
    }
    const opfDir: string = opfRel.includes('/') ? normalizeDir(opfRel.substring(0, opfRel.lastIndexOf('/'))) : '';
    const opf: string = await book.text(normalizeDir(opfRel));
    const title: string = textOf(opf, 'title');
    if (title.length > 0) {
      meta.title = title;
    }
    meta.author = textOf(opf, 'creator');
    meta.publisher = textOf(opf, 'publisher');
    const date: string = textOf(opf, 'date');
    meta.date = date.length >= 10 ? date.substring(0, 10) : date;
    const seriesMatch: RegExpExecArray | null = /<meta\b[^>]*name\s*=\s*"calibre:series"[^>]*>/.exec(opf);
    if (seriesMatch !== null) {
      meta.series = decodeEntities(attributeOf(seriesMatch[0], 'content'));
    }
    const coverId: string = this.coverIdOf(opf);
    let coverHref: string = '';
    const itemPattern: RegExp = /<item\b[^>]*>/g;
    let item: RegExpExecArray | null = itemPattern.exec(opf);
    let refCount: number = 0;
    while (item !== null) {
      const tag: string = item[0];
      const id: string = attributeOf(tag, 'id');
      const href: string = attributeOf(tag, 'href');
      const properties: string = attributeOf(tag, 'properties');
      if (coverHref.length === 0 && href.length > 0) {
        if ((coverId.length > 0 && id === coverId) || properties.indexOf('cover-image') >= 0) {
          coverHref = relativeTo(opfDir, href);
        }
      }
      item = itemPattern.exec(opf);
    }
    if (coverHref.length > 0 && IMAGE_EXT.includes(extensionOf(coverHref))) {
      await this.writeCover(book, coverHref, staged.dir, meta);
    }
    const refPattern: RegExp = /<itemref\b[^>]*>/g;
    let ref: RegExpExecArray | null = refPattern.exec(opf);
    while (ref !== null) {
      refCount++;
      ref = refPattern.exec(opf);
    }
    meta.pages = refCount;
  }

  private async writeCover(book: ZipBook, href: string, dir: string, meta: LocalMeta): Promise<void> {
    const target: string = `${dir}/cover.jpg`;
    try {
      if ((await fs.stat(target)).size > 0) {
        meta.cover = target;
        return;
      }
    } catch (error) {
    }
    try {
      const bytes: ArrayBuffer = await book.read(href);
      LocalFiles.ensureDir(dir);
      const file: fs.File = fs.openSync(target,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        await fs.write(file.fd, bytes);
      } finally {
        fs.closeSync(file);
      }
      meta.cover = target;
    } catch (error) {
    }
  }

  private coverIdOf(opf: string): string {
    const pattern: RegExp = /<meta\b[^>]*name\s*=\s*"cover"[^>]*>/g;
    const match: RegExpExecArray | null = pattern.exec(opf);
    return match !== null ? attributeOf(match[0], 'content') : '';
  }

  private async fillPdf(meta: LocalMeta, staged: StagedFile): Promise<void> {
    if (!canIUse('SystemCapability.OfficeService.PDFService.Core')) {
      return;
    }
    const document: pdfService.PdfDocument = new pdfService.PdfDocument();
    if (document.loadDocument(staged.file) !== pdfService.ParseResult.PARSE_SUCCESS) {
      return;
    }
    meta.pages = document.getPageCount();
    LocalFiles.ensureDir(staged.dir);
    const target: string = `${staged.dir}/cover.jpg`;
    let exists: boolean = false;
    try {
      exists = (await fs.stat(target)).size > 0;
    } catch (error) {
      exists = false;
    }
    if (!exists) {
      try {
        const page: pdfService.PdfPage = document.getPage(0);
        const source: image.PixelMap = page.getPagePixelMap();
        await source.scale(0.34, 0.34);
        const packer: image.ImagePacker = image.createImagePacker();
        const option: image.PackingOption = { format: 'image/jpeg', quality: 82 };
        const buffer: ArrayBuffer = await packer.packing(source, option);
        source.release();
        packer.release();
        const file: fs.File = await fs.open(target,
          fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
        await fs.write(file.fd, buffer);
        await fs.close(file);
      } catch (error) {
      }
    }
    try {
      if ((await fs.stat(target)).size > 0) {
        meta.cover = target;
      }
    } catch (error) {
    }
    try {
      document.releaseDocument();
    } catch (error) {
    }
  }
}

export const localMetas: LocalMetas = new LocalMetas();
