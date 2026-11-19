import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { pdfService } from '@kit.PDFKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { LocalFiles } from './LocalFiles';
import { LocalMeta, localKindOf } from './LocalMeta';
import { ZipBook } from './ZipBook';

export const LOCAL_ORIGIN: string = 'https://lantai.example';

const CACHE_LIMIT: number = 3;
const PAGE_WIDTH: number = 1400;
const TEXT_CHUNK: number = 8000;
const TEXT_CHAPTER_LIMIT: number = 20000;
const PREAMBLE_MERGE: number = 300;

export interface LocalAsset {
  bytes: ArrayBuffer;
  mime: string;
}

interface LocalChapter {
  n: number;
  title: string;
  href: string;
  chars: number;
}

interface LocalChapterMeta {
  n: number;
  title: string;
  chars: number;
  href: string;
}

interface LocalChapterDto {
  chapter: number;
  title: string;
  chars: number;
  href: string;
  html: string;
}

interface LocalBookDto {
  id: string;
  title: string;
  profile: string;
  seriesTitle: string;
  authors: string;
}

interface LocalProgressDto {
  chapter: number;
  progression: number;
}

interface LocalBootstrapDto {
  total: number;
  book: LocalBookDto;
  chapters: LocalChapterMeta[];
  first: LocalChapterDto;
  progress: LocalProgressDto;
}

interface LocalOutlineItem {
  n: number;
  title: string;
  depth: number;
  chars: number;
}

interface LocalOutlineDto {
  outline: LocalOutlineItem[];
}

function extensionOf(name: string): string {
  const dot: number = name.lastIndexOf('.');
  return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
}

function hashOf(text: string): string {
  let hash: number = 5381;
  for (let index: number = 0; index < text.length; index++) {
    hash = ((hash << 5) + hash + text.charCodeAt(index)) & 0x7fffffff;
  }
  return hash.toString(36);
}

function cleanPath(path: string): string {
  const parts: string[] = path.split('/');
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

function decodeHref(href: string): string {
  try {
    return decodeURIComponent(href);
  } catch (error) {
    return href;
  }
}

function normalizePath(baseDir: string, href: string): string {
  const raw: string = decodeHref(href.split('#')[0]);
  if (raw.length === 0) {
    return '';
  }
  if (/^[a-z]+:/i.test(raw)) {
    return '';
  }
  const joined: string = raw.startsWith('/') ? raw.substring(1)
    : (baseDir.length > 0 ? `${baseDir}/${raw}` : raw);
  return cleanPath(joined);
}

function dirOf(path: string): string {
  const slash: number = path.lastIndexOf('/');
  return slash > 0 ? path.substring(0, slash) : '';
}

function attrOf(tag: string, name: string): string {
  const pattern: RegExp = new RegExp(`\\b${name}\\s*=\\s*"([^"]*)"`, 'i');
  const match: RegExpExecArray | null = pattern.exec(tag);
  if (match !== null) {
    return match[1];
  }
  const single: RegExp = new RegExp(`\\b${name}\\s*=\\s*'([^']*)'`, 'i');
  const alt: RegExpExecArray | null = single.exec(tag);
  return alt !== null ? alt[1] : '';
}

function setAttr(tag: string, name: string, value: string): string {
  const pattern: RegExp = new RegExp(`(\\b${name}\\s*=\\s*)(["'])[^"']*\\2`, 'i');
  if (pattern.test(tag)) {
    return tag.replace(pattern, `$1"${value}"`);
  }
  return tag;
}

function dropAttr(tag: string, name: string): string {
  const pattern: RegExp = new RegExp(`\\s+${name}\\s*=\\s*("[^"]*"|'[^']*')`, 'i');
  return tag.replace(pattern, '');
}

function decodeEntities(text: string): string {
  return text.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'").replace(/&amp;/g, '&');
}

function stripTags(text: string): string {
  return decodeEntities(text.replace(/<[^>]*>/g, '')).replace(/\s+/g, ' ').trim();
}

function escapeHtml(text: string): string {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function plainLength(html: string): number {
  return html.replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').replace(/\s+/g, '').length;
}

function decodeText(bytes: ArrayBuffer): string {
  return util.TextDecoder.create('utf-8', { ignoreBOM: true })
    .decodeToString(new Uint8Array(bytes), { stream: false });
}

function encodeText(text: string): ArrayBuffer {
  const bytes: Uint8Array = new util.TextEncoder().encodeInto(text);
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

function mimeOf(path: string): string {
  const clean: string = path.split('?')[0].toLowerCase();
  if (clean.endsWith('.html') || clean.endsWith('.htm') || clean.endsWith('.xhtml') || clean.endsWith('.xht')) {
    return 'text/html';
  }
  if (clean.endsWith('.css')) {
    return 'text/css';
  }
  if (clean.endsWith('.js')) {
    return 'application/javascript';
  }
  if (clean.endsWith('.png')) {
    return 'image/png';
  }
  if (clean.endsWith('.gif')) {
    return 'image/gif';
  }
  if (clean.endsWith('.svg')) {
    return 'image/svg+xml';
  }
  if (clean.endsWith('.webp')) {
    return 'image/webp';
  }
  if (clean.endsWith('.bmp')) {
    return 'image/bmp';
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
  if (clean.endsWith('.mp3')) {
    return 'audio/mpeg';
  }
  if (clean.endsWith('.mp4')) {
    return 'video/mp4';
  }
  return 'image/jpeg';
}

class OpenedLocal {
  id: string = '';
  kind: string = '';
  profile: string = 'EPUB';
  title: string = '';
  author: string = '';
  series: string = '';
  path: string = '';
  dir: string = '';
  opfDir: string = '';
  chapters: LocalChapter[] = [];
  texts: string[] = [];
  zip: ZipBook | null = null;
  doc: pdfService.PdfDocument | null = null;
}

export class LocalBookSource {
  private base: string = '';
  private cacheDir: string = '';
  private metas: Map<string, LocalMeta> = new Map<string, LocalMeta>();
  private opened: Map<string, OpenedLocal> = new Map<string, OpenedLocal>();
  private order: string[] = [];
  private pdfBusy: boolean = false;

  init(ctx: common.Context): void {
    if (this.base.length > 0) {
      return;
    }
    this.base = `${ctx.filesDir}/local`;
    this.cacheDir = `${ctx.cacheDir}/pdf-page`;
  }

  setMetas(metas: LocalMeta[]): void {
    const alive: Set<string> = new Set<string>();
    for (let index: number = 0; index < metas.length; index++) {
      alive.add(metas[index].id);
      this.metas.set(metas[index].id, metas[index]);
    }
    const stale: string[] = [];
    this.metas.forEach((value: LocalMeta, key: string) => {
      if (!alive.has(key)) {
        stale.push(key);
      }
    });
    for (let index: number = 0; index < stale.length; index++) {
      this.forget(stale[index]);
    }
  }

  metaOf(id: string): LocalMeta | null {
    const hit: LocalMeta | undefined = this.metas.get(id);
    return hit === undefined ? null : hit;
  }

  forget(id: string): void {
    this.metas.delete(id);
    const opened: OpenedLocal | undefined = this.opened.get(id);
    if (opened !== undefined) {
      this.release(opened);
      this.opened.delete(id);
    }
    this.order = this.order.filter((key: string) => key !== id);
  }

  releaseAll(): void {
    this.opened.forEach((value: OpenedLocal) => {
      this.release(value);
    });
    this.opened.clear();
    this.order = [];
  }

  async dropPages(id: string): Promise<void> {
    if (this.cacheDir.length === 0) {
      return;
    }
    await LocalFiles.removeTree(`${this.cacheDir}/${hashOf(id)}`);
  }

  async preflight(id: string): Promise<string> {
    const meta: LocalMeta | null = this.metaOf(id);
    if (meta === null) {
      return '这本书还没有完成解析';
    }
    if (this.opened.has(id) || this.base.length === 0) {
      return '';
    }
    const path: string = this.stagedPath(meta);
    if (await LocalFiles.exists(path)) {
      return '';
    }
    try {
      await LocalFiles.copyInto(meta.uri, path);
      return '';
    } catch (error) {
      return '原文件已无法访问，请重新导入';
    }
  }

  private stagedPath(meta: LocalMeta): string {
    const ext: string = extensionOf(meta.name);
    return `${this.base}/${hashOf(meta.uri)}/book${ext.length > 0 ? '.' + ext : ''}`;
  }

  private release(opened: OpenedLocal): void {
    if (opened.doc !== null) {
      try {
        opened.doc.releaseDocument();
      } catch (error) {
      }
      opened.doc = null;
    }
    opened.zip = null;
    opened.texts = [];
  }

  private remember(id: string, opened: OpenedLocal): void {
    this.opened.set(id, opened);
    this.order = this.order.filter((key: string) => key !== id);
    this.order.push(id);
    while (this.order.length > CACHE_LIMIT) {
      const oldest: string | undefined = this.order.shift();
      if (oldest === undefined) {
        break;
      }
      const dropped: OpenedLocal | undefined = this.opened.get(oldest);
      if (dropped !== undefined && dropped.id !== id) {
        this.release(dropped);
        this.opened.delete(oldest);
      }
    }
  }

  async bootstrap(id: string, chapter: number): Promise<string> {
    const opened: OpenedLocal = await this.ensure(id);
    const meta: LocalMeta | null = this.metaOf(id);
    const total: number = opened.chapters.length;
    let start: number = chapter > 0 ? chapter : 1;
    if (start > total) {
      start = total;
    }
    const first: LocalChapterDto = await this.chapterDto(opened, start);
    const list: LocalChapterMeta[] = [];
    for (let index: number = 0; index < total && index < 8; index++) {
      const item: LocalChapter = opened.chapters[index];
      list.push({ n: item.n, title: item.title, chars: item.chars, href: item.href });
    }
    const book: LocalBookDto = {
      id: id,
      title: opened.title,
      profile: opened.profile,
      seriesTitle: opened.series,
      authors: opened.author
    };
    const progressChapter: number = meta !== null && meta.chapter > 0 ? meta.chapter : 1;
    const progress: LocalProgressDto = {
      chapter: progressChapter,
      progression: meta !== null ? meta.progress : 0
    };
    const payload: LocalBootstrapDto = {
      total: total,
      book: book,
      chapters: list,
      first: first,
      progress: progress
    };
    return JSON.stringify(payload);
  }

  async chapter(id: string, n: number): Promise<string> {
    const opened: OpenedLocal = await this.ensure(id);
    const dto: LocalChapterDto = await this.chapterDto(opened, n);
    return JSON.stringify(dto);
  }

  async outline(id: string): Promise<string> {
    const opened: OpenedLocal = await this.ensure(id);
    const items: LocalOutlineItem[] = [];
    for (let index: number = 0; index < opened.chapters.length; index++) {
      const item: LocalChapter = opened.chapters[index];
      items.push({ n: item.n, title: item.title, depth: 0, chars: item.chars });
    }
    const payload: LocalOutlineDto = { outline: items };
    return JSON.stringify(payload);
  }

  async asset(id: string, path: string): Promise<LocalAsset> {
    const opened: OpenedLocal = await this.ensure(id);
    if (path.startsWith('page:')) {
      const page: number = parseInt(path.substring(5), 10);
      const bytes: ArrayBuffer = await this.pdfPage(opened, page);
      return { bytes: bytes, mime: 'image/jpeg' };
    }
    const book: ZipBook | null = opened.zip;
    if (book === null) {
      return { bytes: new ArrayBuffer(0), mime: 'text/plain' };
    }
    const clean: string = cleanPath(decodeHref(path));
    const mime: string = mimeOf(clean);
    try {
      const bytes: ArrayBuffer = await book.read(clean);
      if (mime === 'text/css') {
        const css: string = this.rewriteCss(id, decodeText(bytes), dirOf(clean));
        return { bytes: encodeText(css), mime: mime };
      }
      return { bytes: bytes, mime: mime };
    } catch (error) {
      return { bytes: new ArrayBuffer(0), mime: mime };
    }
  }

  private async ensure(id: string): Promise<OpenedLocal> {
    const hit: OpenedLocal | undefined = this.opened.get(id);
    if (hit !== undefined) {
      return hit;
    }
    const meta: LocalMeta | null = this.metaOf(id);
    if (meta === null) {
      throw new Error('本地书不存在');
    }
    if (this.base.length === 0) {
      throw new Error('本机目录未初始化');
    }
    const opened: OpenedLocal = new OpenedLocal();
    opened.id = id;
    opened.kind = meta.kind.length > 0 ? meta.kind : localKindOf(meta.name);
    opened.profile = meta.profile.length > 0 ? meta.profile : 'EPUB';
    opened.title = meta.title.length > 0 ? meta.title : meta.name;
    opened.author = meta.author;
    opened.series = meta.series;
    opened.dir = `${this.base}/${hashOf(meta.uri)}`;
    opened.path = this.stagedPath(meta);
    if (!(await LocalFiles.exists(opened.path))) {
      await LocalFiles.copyInto(meta.uri, opened.path);
    }
    if (opened.kind === 'epub') {
      await this.indexEpub(opened);
    } else if (opened.kind === 'txt') {
      await this.indexText(opened);
    } else if (opened.kind === 'pdf') {
      await this.indexPdf(opened);
    } else {
      throw new Error('该格式不支持统一阅读');
    }
    if (opened.chapters.length === 0) {
      throw new Error('没有可显示的内容');
    }
    this.remember(id, opened);
    return opened;
  }

  private async indexEpub(opened: OpenedLocal): Promise<void> {
    const book: ZipBook = await ZipBook.open(opened.path);
    opened.zip = book;
    const container: string = await book.text('META-INF/container.xml');
    const rootTag: RegExpExecArray | null = /<rootfile\b[^>]*>/.exec(container);
    const opfRel: string = rootTag !== null ? attrOf(rootTag[0], 'full-path') : '';
    if (opfRel.length === 0) {
      throw new Error('EPUB 缺少 OPF');
    }
    const opfPath: string = cleanPath(decodeHref(opfRel));
    const opfDir: string = dirOf(opfPath);
    opened.opfDir = opfDir;
    const opf: string = await book.text(opfPath);
    const manifest: Map<string, string> = new Map<string, string>();
    const types: Map<string, string> = new Map<string, string>();
    const navIds: string[] = [];
    const itemPattern: RegExp = /<item\b[^>]*>/g;
    let item: RegExpExecArray | null = itemPattern.exec(opf);
    while (item !== null) {
      const tag: string = item[0];
      const id: string = attrOf(tag, 'id');
      const href: string = attrOf(tag, 'href');
      if (id.length > 0 && href.length > 0) {
        manifest.set(id, normalizePath(opfDir, href));
        types.set(id, attrOf(tag, 'media-type'));
        const properties: string = attrOf(tag, 'properties');
        if (properties.indexOf('nav') >= 0 || attrOf(tag, 'media-type') === 'application/x-dtbncx+xml') {
          navIds.push(id);
        }
      }
      item = itemPattern.exec(opf);
    }
    const order: string[] = [];
    const refPattern: RegExp = /<itemref\b[^>]*>/g;
    let ref: RegExpExecArray | null = refPattern.exec(opf);
    while (ref !== null) {
      const idref: string = attrOf(ref[0], 'idref');
      if (idref.length > 0) {
        order.push(idref);
      }
      ref = refPattern.exec(opf);
    }
    const titles: Map<string, string> = await this.epubTitles(book, navIds, manifest, types);
    for (let index: number = 0; index < order.length; index++) {
      const idref: string = order[index];
      const href: string | undefined = manifest.get(idref);
      if (href === undefined || href.length === 0) {
        continue;
      }
      const type: string = types.get(idref) !== undefined ? types.get(idref) as string : '';
      if (type.length > 0 && type.indexOf('html') < 0) {
        continue;
      }
      const title: string | undefined = titles.get(href);
      const fallback: string = `第 ${opened.chapters.length + 1} 节`;
      opened.chapters.push({
        n: opened.chapters.length + 1,
        title: title !== undefined && title.length > 0 ? title : fallback,
        href: href,
        chars: 0
      });
    }
  }

  private async epubTitles(book: ZipBook, navIds: string[], manifest: Map<string, string>,
    types: Map<string, string>): Promise<Map<string, string>> {
    const titles: Map<string, string> = new Map<string, string>();
    for (let index: number = 0; index < navIds.length; index++) {
      const href: string | undefined = manifest.get(navIds[index]);
      if (href === undefined || href.length === 0) {
        continue;
      }
      const type: string = types.get(navIds[index]) !== undefined ? types.get(navIds[index]) as string : '';
      let source: string = '';
      try {
        source = await book.text(href);
      } catch (error) {
        continue;
      }
      const base: string = dirOf(href);
      if (type.indexOf('ncx') >= 0) {
        const pointPattern: RegExp = /<navPoint\b[\s\S]*?<text[^>]*>([\s\S]*?)<\/text>[\s\S]*?<content\b[^>]*>/g;
        let point: RegExpExecArray | null = pointPattern.exec(source);
        while (point !== null) {
          const title: string = stripTags(point[1]);
          const src: string = attrOf(point[0], 'src');
          const target: string = normalizePath(base, src);
          if (title.length > 0 && target.length > 0 && !titles.has(target)) {
            titles.set(target, title);
          }
          point = pointPattern.exec(source);
        }
        continue;
      }
      const linkPattern: RegExp = /<a\b[^>]*href\s*=\s*"([^"]*)"[^>]*>([\s\S]*?)<\/a>/g;
      let link: RegExpExecArray | null = linkPattern.exec(source);
      while (link !== null) {
        const title: string = stripTags(link[2]);
        const target: string = normalizePath(base, link[1]);
        if (title.length > 0 && target.length > 0 && !titles.has(target)) {
          titles.set(target, title);
        }
        link = linkPattern.exec(source);
      }
    }
    if (titles.size > 0) {
      return titles;
    }
    for (let index: number = 0; index < navIds.length; index++) {
      const href: string | undefined = manifest.get(navIds[index]);
      if (href === undefined) {
        continue;
      }
      let source: string = '';
      try {
        source = await book.text(href);
      } catch (error) {
        continue;
      }
      const base: string = dirOf(href);
      const linkPattern: RegExp = /<a\b[^>]*href\s*=\s*"([^"]*)"[^>]*>([\s\S]*?)<\/a>/g;
      let link: RegExpExecArray | null = linkPattern.exec(source);
      while (link !== null) {
        const title: string = stripTags(link[2]);
        const target: string = normalizePath(base, link[1]);
        if (title.length > 0 && target.length > 0 && !titles.has(target)) {
          titles.set(target, title);
        }
        link = linkPattern.exec(source);
      }
    }
    return titles;
  }

  private async indexText(opened: OpenedLocal): Promise<void> {
    const raw: string = await fs.readText(opened.path);
    const text: string = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    const lines: string[] = text.split('\n');
    const heads: number[] = [];
    for (let index: number = 0; index < lines.length; index++) {
      if (this.isHeading(lines[index])) {
        heads.push(index);
      }
    }
    if (heads.length >= 2) {
      let cursor: number = 0;
      for (let index: number = 0; index < heads.length; index++) {
        const start: number = heads[index];
        const end: number = index + 1 < heads.length ? heads[index + 1] : lines.length;
        const lead: string[] = start > cursor ? lines.slice(cursor, start) : [];
        if (lead.length > 0 && index === 0 && plainLength(lead.join('')) <= PREAMBLE_MERGE) {
          this.pushText(opened, lead.concat(lines.slice(start, end)), lines[start].trim());
        } else {
          if (lead.length > 0) {
            this.pushText(opened, lead, '');
          }
          this.pushText(opened, lines.slice(start, end), lines[start].trim());
        }
        cursor = end;
      }
      if (cursor < lines.length) {
        this.pushText(opened, lines.slice(cursor), '');
      }
    }
    if (opened.chapters.length === 0) {
      let cursor: number = 0;
      while (cursor < text.length) {
        let end: number = Math.min(text.length, cursor + TEXT_CHUNK);
        if (end < text.length) {
          const next: number = text.indexOf('\n', end);
          if (next > 0 && next - end < 2000) {
            end = next + 1;
          }
        }
        this.pushText(opened, text.substring(cursor, end).split('\n'), '');
        cursor = end;
      }
    }
    if (opened.chapters.length === 0) {
      this.pushText(opened, [''], '');
    }
  }

  private isHeading(line: string): boolean {
    const trimmed: string = line.trim();
    if (trimmed.length === 0 || trimmed.length > 40) {
      return false;
    }
    return /^第[0-9零一二三四五六七八九十百千两]{1,12}[章节回卷篇集部]/.test(trimmed);
  }

  private pushText(opened: OpenedLocal, lines: string[], title: string): void {
    let body: string = '';
    for (let index: number = 0; index < lines.length; index++) {
      const line: string = lines[index];
      if (line.trim().length === 0) {
        continue;
      }
      body += `<p>${escapeHtml(line)}</p>`;
      if (body.length > TEXT_CHAPTER_LIMIT) {
        break;
      }
    }
    if (body.length === 0 && title.length === 0) {
      return;
    }
    const n: number = opened.chapters.length + 1;
    const label: string = title.length > 0 ? escapeHtml(title) : `第 ${n} 节`;
    opened.texts.push(`<div class="txt-body">${body}</div>`);
    opened.chapters.push({ n: n, title: title.length > 0 ? title : label, href: `txt:${n}`, chars: plainLength(body) });
  }

  private async indexPdf(opened: OpenedLocal): Promise<void> {
    if (!canIUse('SystemCapability.OfficeService.PDFService.Core')) {
      throw new Error('当前设备缺少 PDF 渲染能力');
    }
    const document: pdfService.PdfDocument = new pdfService.PdfDocument();
    const result: pdfService.ParseResult = document.loadDocument(opened.path);
    if (result !== pdfService.ParseResult.PARSE_SUCCESS) {
      throw new Error(`PDF 解析失败（${result as number}）`);
    }
    opened.doc = document;
    const total: number = document.getPageCount();
    for (let index: number = 0; index < total; index++) {
      const n: number = index + 1;
      opened.chapters.push({ n: n, title: `第 ${n} 页`, href: `page:${n}`, chars: 0 });
    }
  }

  private async chapterDto(opened: OpenedLocal, n: number): Promise<LocalChapterDto> {
    let target: LocalChapter | null = null;
    for (let index: number = 0; index < opened.chapters.length; index++) {
      if (opened.chapters[index].n === n) {
        target = opened.chapters[index];
        break;
      }
    }
    if (target === null) {
      throw new Error('章节不存在');
    }
    const html: string = await this.htmlOf(opened, target);
    const dto: LocalChapterDto = {
      chapter: target.n,
      title: target.title,
      chars: target.chars > 0 ? target.chars : plainLength(html),
      href: target.href,
      html: html
    };
    return dto;
  }

  private async htmlOf(opened: OpenedLocal, chapter: LocalChapter): Promise<string> {
    if (opened.kind === 'epub') {
      return await this.epubHtml(opened, chapter);
    }
    if (opened.kind === 'txt') {
      const index: number = chapter.n - 1;
      return index >= 0 && index < opened.texts.length ? opened.texts[index] : '<p>（本章为空）</p>';
    }
    return `<div class="pdf-page"><img src="${this.assetUrl(opened.id, `page:${chapter.n}`)}" alt="" /></div>`;
  }

  private async epubHtml(opened: OpenedLocal, chapter: LocalChapter): Promise<string> {
    const book: ZipBook | null = opened.zip;
    if (book === null) {
      throw new Error('EPUB 未打开');
    }
    let source: string = '';
    try {
      source = await book.text(chapter.href);
    } catch (error) {
      return '<p>（本章读取失败）</p>';
    }
    const bodyPattern: RegExp = /<body\b[^>]*>([\s\S]*)<\/body>/i;
    const match: RegExpExecArray | null = bodyPattern.exec(source);
    let body: string = match !== null ? match[1] : source;
    const base: string = dirOf(chapter.href);
    body = this.rewriteEpub(opened, body, base);
    return body;
  }

  private spineIndex(opened: OpenedLocal): Map<string, number> {
    const index: Map<string, number> = new Map<string, number>();
    for (let cursor: number = 0; cursor < opened.chapters.length; cursor++) {
      index.set(opened.chapters[cursor].href, opened.chapters[cursor].n);
    }
    return index;
  }

  private rewriteEpub(opened: OpenedLocal, html: string, base: string): string {
    const spine: Map<string, number> = this.spineIndex(opened);
    let out: string = this.mapTags(html, 'link', (tag: string): string => {
      const href: string = attrOf(tag, 'href');
      if (href.length === 0) {
        return tag;
      }
      const path: string = normalizePath(base, href);
      return path.length > 0 ? setAttr(tag, 'href', this.assetUrl(opened.id, path)) : tag;
    });
    out = this.mapTags(out, 'a', (tag: string): string => {
      const href: string = attrOf(tag, 'href');
      if (href.length === 0) {
        return tag;
      }
      const path: string = normalizePath(base, href);
      const target: number | undefined = spine.get(path);
      if (target === undefined) {
        return tag;
      }
      return setAttr(dropAttr(tag, 'href'), 'data-ch', `${target}`);
    });
    out = this.rewriteSources(opened, out, base, 'img');
    out = this.rewriteSources(opened, out, base, 'image');
    out = this.rewriteSources(opened, out, base, 'source');
    out = this.rewriteSources(opened, out, base, 'video');
    out = this.rewriteSources(opened, out, base, 'audio');
    out = this.rewriteSources(opened, out, base, 'script');
    out = this.rewriteSources(opened, out, base, 'iframe');
    out = this.rewriteUrls(out, base, opened.id);
    return out;
  }

  private rewriteSources(opened: OpenedLocal, html: string, base: string, name: string): string {
    return this.mapTags(html, name, (tag: string): string => {
      let next: string = tag;
      const attrs: string[] = ['src', 'xlink:href', 'poster', 'data-src'];
      for (let index: number = 0; index < attrs.length; index++) {
        const value: string = attrOf(next, attrs[index]);
        if (value.length === 0) {
          continue;
        }
        const path: string = normalizePath(base, value);
        if (path.length > 0) {
          next = setAttr(next, attrs[index], this.assetUrl(opened.id, path));
        }
      }
      return next;
    });
  }

  private rewriteUrls(text: string, base: string, id: string): string {
    const pattern: RegExp = /url\(\s*(['"]?)([^'")]+)\1\s*\)/gi;
    let out: string = '';
    let last: number = 0;
    let match: RegExpExecArray | null = pattern.exec(text);
    while (match !== null) {
      const raw: string = match[2];
      out += text.substring(last, match.index);
      if (/^(data:|https?:|\/\/|#)/i.test(raw)) {
        out += match[0];
      } else {
        const path: string = normalizePath(base, raw);
        out += path.length > 0 ? `url("${this.assetUrl(id, path)}")` : match[0];
      }
      last = match.index + match[0].length;
      match = pattern.exec(text);
    }
    return out + text.substring(last);
  }

  private rewriteCss(id: string, css: string, base: string): string {
    const imports: string = css.replace(/@import\s+(['"])([^'"]+)\1/gi, '@import url($1$2$1)');
    return this.rewriteUrls(imports, base, id);
  }

  private mapTags(html: string, name: string, fn: (tag: string) => string): string {
    const pattern: RegExp = new RegExp(`<${name}\\b[^>]*>`, 'gi');
    let out: string = '';
    let last: number = 0;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      out += html.substring(last, match.index) + fn(match[0]);
      last = match.index + match[0].length;
      match = pattern.exec(html);
    }
    return out + html.substring(last);
  }

  private assetUrl(id: string, path: string): string {
    return `${LOCAL_ORIGIN}/api/lantai/v1/read/${id}/asset?p=${encodeURIComponent(path)}`;
  }

  private async pdfPage(opened: OpenedLocal, page: number): Promise<ArrayBuffer> {
    const target: string = `${this.cacheDir}/${hashOf(opened.id)}/${page}.jpg`;
    if (await LocalFiles.exists(target)) {
      return await this.readAll(target);
    }
    while (this.pdfBusy) {
      await new Promise<void>((resolve: () => void) => {
        setTimeout(resolve, 30);
      });
    }
    this.pdfBusy = true;
    try {
      if (await LocalFiles.exists(target)) {
        return await this.readAll(target);
      }
      const bytes: ArrayBuffer = await this.renderPage(opened, page);
      LocalFiles.ensureDir(`${this.cacheDir}/${hashOf(opened.id)}`);
      const file: fs.File = fs.openSync(target, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try {
        await fs.write(file.fd, bytes);
      } finally {
        fs.closeSync(file);
      }
      return bytes;
    } finally {
      this.pdfBusy = false;
    }
  }

  private async renderPage(opened: OpenedLocal, page: number): Promise<ArrayBuffer> {
    const document: pdfService.PdfDocument | null = opened.doc;
    if (document === null) {
      throw new Error('PDF 未打开');
    }
    const pdfPage: pdfService.PdfPage = document.getPage(page - 1);
    const pixel: image.PixelMap = pdfPage.getPagePixelMap();
    try {
      const info: image.ImageInfo = await pixel.getImageInfo();
      const ratio: number = PAGE_WIDTH / Math.max(1, info.size.width);
      if (ratio < 1) {
        await pixel.scale(ratio, ratio);
      }
      const packer: image.ImagePacker = image.createImagePacker();
      try {
        const option: image.PackingOption = { format: 'image/jpeg', quality: 80 };
        return await packer.packing(pixel, option);
      } finally {
        packer.release();
      }
    } finally {
      pixel.release();
    }
  }

  private async readAll(path: string): Promise<ArrayBuffer> {
    const file: fs.File = await fs.open(path, fs.OpenMode.READ_ONLY);
    try {
      const size: number = (await fs.stat(file.fd)).size;
      const buffer: ArrayBuffer = new ArrayBuffer(size);
      await fs.read(file.fd, buffer);
      return buffer;
    } finally {
      await fs.close(file);
    }
  }
}

export const localBookSource: LocalBookSource = new LocalBookSource();
